%*-----------------------------------------------------------------------------*
%* Program name       : scan_compares.sas
%* Version            : 1.0
%* Purpose            : Scan all of the COMPARE outputs in the location and summarize issues
%* Author             : Lukasz Kulakowski (w/ help of GROKs deeper search)
%* Date created       : 14Jul2025	
%*-----------------------------------------------------------------------------*
%* PARAMS
%*      dir   = a path to a directory holding output files with compare results
%*              in a format of /root/.../output (dont add the slash at the end)
%*      debug = a debug mode, when set to Y, will keep variables and temporary 
%*              datasets to debug and test
%*-----------------------------------------------------------------------------*;
%* Revision history   : 
%* Date               : 14Jul2025
%* Author             : LK
%* Version            : 1.0
%* Revision           : Initial version
%*-----------------------------------------------------------------------------*;
%* Notes              :
%* - proc comapre outputs are stored in .lst files
%* - one .lst output can contain multiple compares, thus multiple compare openings
%*-----------------------------------------------------------------------------*;
%* Some useful details from SAS DOCS;
%* PROC COMPARE generates the following information about the two data sets that are being compared:;
%* 1. whether matching variables have different values;
%* 2. whether one data set has more observations than the other;
%* 3. what variables the two data sets have in common ;
%* 4. how many variables are in one data set but not in the other;
%* 5. whether matching variables have different formats, labels, or types;
%* 6. a comparison of the values of matching observations;
%*-----------------------------------------------------------------------------*;
%* Macro assumes the following messages are available in the output to perform checks
0. Opening for the procedure output: 
[X] The COMPARE Procedure
1. whether matching variables have different values
[X] Total Number of Values which Compare Unequal
2. whether one data set has more observations than the others
[X] Number of Observations in WORK.COMPARE but not in WORK.BASE: 1.
3. what variables the two data sets have in common
[X] WARNING: The data sets WORK.BASE3 and WORK.COMPARE3 have no variables in common. There are no matching variables to compare.
4. how many variables are in one data set but not in the other
[X] Number of Variables in WORK.COMPARE but not in WORK.BASE: 1.
5. whether matching variables have different formats, labels, or types
[X] Number of Variables with Differing Attributes:
[X] Number of Variables with Conflicting Types:
6. a comparison of the values of matching observations
[X] Number of Observations with Some Compared Variables Unequal: 1.
[X] Number of Variables Compared with Some Observations Unequal: 1.
[X] All Variables Compared have Unequal Values
%*-----------------------------------------------------------------------------*;

%macro scan_compares(dir=,debug=N);

    %*Get the list of all RTF outputs in the given dir;
    data lst_files;
        length file_path $200;

        %*obtain the fileref;
        rc=filename('fref', "&dir./");
        if rc=0 then do;
            did=dopen('fref');
            rc=filename('fref');
        end;
        %*if it failed, get the message;
        else do;
            length msg $200.;
            msg=sysmsg();
            put msg=;
            did=.;
        end;

        %*check if the directory opened;
        if did <= 0 then put "ERR%STR()OR: Unable to open directory.";

        %*get the number of members in the directory;
        dnum=dnum(did);

        %*loop over the number of members;
        do i=1 to dnum;
            file_name=dread(did, i);
            if lowcase(scan(file_name, -1, '.'))='lst' then do;
                file_path="&dir./"
                    || file_name;
                output;
            end;
        end;

        %*close the fileref;
        rc=dclose(did);

        keep file_path;
    run;

    %*Get the list of LST files;
    proc sql noprint;
        select count(*) into :n_files from lst_files;
        select file_path into :file1 - :file%left(&n_files) from lst_files;
    quit;

    %*Initialize the output dataset;
    data failed_compares;
        length file_name $200 compare_datasets $200 has_differences 8;
        stop;
    run;

    %* Step 4: Process each LST file;
    %do i=1 %to &n_files;
        %let file=&&file&i;

        %*Parse the LST file directly;
        data failed_compares_temp;
            length file_name $200 compare_datasets $200 line $32767 diff_val 8;
            
            retain compare_datasets '' has_differences 0 file_name '';

            %*identify the file to read;
            infile "&&file" lrecl=32767 end=eof;
            input;
            line=_infile_;

            file_name = "&&file";

            %*Read in the beginning of report;
            if index(line, 'The COMPARE Procedure') > 0 then do;
                %*check if we are still checking the same output that spans over mulitple pages;
                input;
                new_compare_datasets = strip(compress(_infile_,'09'x));

                %*are we starting new compare?;
                if compare_datasets ne new_compare_datasets then do;
                    if has_differences = 1 then do;
                        %if %upcase(&debug) ne Y %then %do;
                            output;
                        %end;
                    end;

                    %*cleanup;
                    compare_datasets = new_compare_datasets;
                    has_differences = 0;
                    diff_val = .;

                end;
            end;

            %*#########################################################################;
            %*##################          RULE DEFINITIONS         ####################;
            %*#########################################################################;
            %*Rule;
            else if index(line, 'Number of Variables in') > 0 and 
               index(line, 'but not in') > 0 then do;
                diff_val = input(compress(scan(line, -1)), 8.);
                if diff_val > 0 then has_differences = 1;
            end; 
            %*Rule;
            else if index(line, 'Number of Observations in') > 0 and 
               index(line, 'but not in') > 0 then do;
                diff_val = input(compress(scan(line, -1)), 8.);
                if diff_val > 0 then has_differences = 1;
            end; 
            %*Rule;
            else if index(line, 'Number of Observations with Some Compared Variables Unequal:') > 0 then do;
                diff_val=input(compress(scan(line, -1)), 8.);
                if diff_val > 0 then has_differences=1;
            end;
            %*Rule;
            else if index(line, 'Number of Observations with All Compared Variables Unequal:') > 0 then do;
                diff_val=input(compress(scan(line, -1)), 8.);
                if diff_val > 0 then has_differences=1;
            end;
            %*Rule;
            else if index(line, 'Number of Variables Compared with Some Observations Unequal:') > 0 then do;
                diff_val=input(compress(scan(line, -1)), 8.);
                if diff_val > 0 then has_differences=1;
            end;
            %*Rule;
            else if index(line, 'Number of Variables Compared with All Observations Unequal:') > 0 then do;
                diff_val=input(compress(scan(line, -1)), 8.);
                if diff_val > 0 then has_differences=1;
            end;
            %*Rule;
            else if index(line, 'All Variables Compared have Unequal Values') > 0 then do;
                has_differences=1;
            end;
            %*Rule;
            else if index(line, 'have no variables in common') > 0 and 
                index(line, 'There are no matching variables to compare') > 0 then do;
                has_differences=1;
            end;
            %*Rule;
            else if index(line, 'Number of Variables with Conflicting Types:') > 0 then do;
                diff_val=input(compress(scan(line, -1)), 8.);
                if diff_val > 0 then has_differences=1;
            end;
            %*Rule;
            else if index(line, 'Number of Variables with Differing Attributes:') > 0 then do;
                diff_val=input(compress(scan(line, -1)), 8.);
                if diff_val > 0 then has_differences=1;
            end;
            %*Rule;
            else if index(line, 'Total Number of Values which Compare Unequal:') > 0 then do;
                diff_val=input(compress(scan(line, -1)), 8.);
                if diff_val > 0 then has_differences=1;
            end;
            %*#########################################################################;

            if eof and has_differences = 1 then do;
                %if %upcase(&debug) ne Y %then %do;
                    output;
                %end;
            end;
            
            %if %upcase(&debug) ne Y %then %do;
                keep file_name compare_datasets has_differences;
            %end;
        run;

        %*Append results to master dataset;
        proc append base=failed_compares data=failed_compares_temp force;
        run;
    %end;

    %*cleanup;
    %if %upcase(&debug) ne Y %then %do;
        proc datasets library=work nolist;
            delete lst_files failed_compares_temp;
        run;
    %end;
    %else %do;
        %put WARN%STR()ING: Macro is running in debug mode;
    %end;

%mend scan_compares;

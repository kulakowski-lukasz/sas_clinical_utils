# Summary


## scan_comapres.sas 
> Gathers all of the ".lst" files from a given directory and searches for proc compare outputs within them
> When found, it will analyze the output and create a row in failed_compares dataset whenever a rule is tiggered
> Rules are based on SAS docs, can be easily found in the code

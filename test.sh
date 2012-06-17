#!/usr/local/bin/bash

# thread testing 
#
# WARNING: below are my observations from the testing ive done. i'm not
# sure that my finding will be universal, or applicable under 
# varying network conditions. take this with a grain of salt.
#
# i experience dns resolution issues at < 20 threads, and > 500 at 
# multiple locations.
# 30 - 300 seems to be the sweet spot, where these numbers of threads offer the same performance, and produce no (or at least very few) failures.
# the range syntax here (min..max..increment)requires bash 4i
# we're testing for 2 metrics:
# 1) the time to complete, via the "time" command
# 2) the number of dns resolution failures (via the grep piped to wc -l), see the above for an explanation.
for i in {200..500..100}
do
  for store in $@
  do 
    echo "starting testing for $store using $i threads:"
    time ./dl.rb -s $store -t $i | grep "Couldn't download" | wc -l
  done
done


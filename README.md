# SAS Macros

Mac's collection of SAS macros and maybe code too. To use, clone and INCLUDE. For example:

    $ git clone https://github.com/gaulinmp/sas_macros.git /tmp/path_of_greatness

Then in SAS:

    $ sas -nodms
    1? %INCLUDE "/tmp/path_of_greatness/MACROS.SAS";

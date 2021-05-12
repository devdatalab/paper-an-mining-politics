# paper-an-mining-politics

Code and data to replicate Asher and Novosad, "Rent-Seeking and Criminal Politicians:
Evidence from Mining Booms", <i>Review of Economics and Statistics</i>. A draft of the paper can be found here: http://paulnovosad.com/pdf/asher-novosad-mining-politics.pdf

Link to data for replication: https://drive.google.com/file/d/1oaiMFVpcyHuFb1qf0ZOrxmR4mVEJoppU/view?usp=sharing

Link to same dataset on the Harvard Dataverse:
https://doi.org/10.7910/DVN/BMBDFC

To regenerate the tables and figures from the paper, take the
following steps:

1. Download and unzip the replication data package from the data link above.

2. Clone this repo and go to the root repo folder.

3. Open the do file make_mining.do, and set the globals `out`,
   `tmp`, `mining`, and `mdata`.
   * `out` is the target folder for all outputs, such as tables
   and graphs. 
   * `tmp` is a folder for data files and
   temporary data files.
   * `mdata` and `mining` both should point to the downloaded data folder. 
   * `mcode` is the code folder of the clone of the replication repo, but can stay as `.` if running from the current folder.

4. Run `make_mining.do`.  This will run through  the
  do files in`a/` to regenerate the main tables and figures.

5. Some of the estimation output commands require a functioning python installation. Please do not contact us if you have a hard time getting python to work. Our python configuration is hanging by a thread and we are afraid even to look at it in case something breaks irreparably.
   
Please note we use globals for pathnames, which will cause errors if
   filepaths have spaces in them. Please store code and data in paths
   that can be access without spaces in filenames.
   
This code was tested using Stata 16.0 in Linux and Mac environments and generates the primary tables on our research server in less than a minute.

# Author: Glen Adams

import os
import urllib
from datetime import datetime
import subprocess

url = r"https://waterservices.usgs.gov/nwis/iv/?format=rdb&stateCd=<REPLACEME>&variable=72019&siteType=GW&siteStatus=active&period=P1D"
workdir = os.getcwd()
fileLoc = os.path.join(workdir, "usgsData")
urllib.urlretrieve(url, fileLoc)
curDate = datetime.today().strftime('%Y-%m-%d')
lookupCoordsURL = r"https://waterdata.usgs.gov/nwis/inventory?search_site_no=<REPLACEME>&search_site_no_match_type=exact&group_key=NONE&format=sitefile_output&sitefile_output_format=rdb&column_name=dec_lat_va&column_name=dec_long_va&list_of_search_criteria=search_site_no"
knownSites = {}
tempLookupFile = os.path.join(workdir, "tempLookupFile")

# TODO: Rewrite to use pandas/geopandas. Don't spam USGS with lookups every time, see if we already have that location's coordinates.
with open(fileLoc, 'r') as f:
    if os.path.exists(os.path.join(workdir, "edited_data.csv")):
        os.remove(os.path.join(workdir, "edited_data.csv"))
    with open(os.path.join(workdir, "edited_data.csv"), "a+") as outputFile:
        outputFile.write("uid,agency,site_no,datetime,tz_cd,Depth_toWL_ft\n")
        for line in f:
            if line[0:4] == "USGS":
                header = line
                line = line.split("\t")
                if curDate in line[2] and line[4] != "Tst" and line[4]:
                    if line[1] not in knownSites.keys():
                        urllib.urlretrieve(lookupCoordsURL.replace("<REPLACEME>", line[1]), tempLookupFile)
                        with open(tempLookupFile, 'r') as lookupFile:
                            lastLine = lookupFile.readlines()[-1].split("\t")
                        knownSites[line[1]] = lastLine[0] + "," + lastLine[1]
                    if line[2].split(':')[1] in ("00", "15", "30", "45"):
                        outputFile.write(str(line[1]) + "_" + str(line[2]) + "," +
                                         line[0] + "," +
                                         line[1] + "," +
                                         line[2] + "," +
                                         line[3] + "," +
                                         line[4] + "," +
                                         knownSites[line[1]] + "\n")
print os.path.join(workdir, "InsertData.sh")
subprocess.call(os.path.join(workdir, "InsertData.sh"))
os.remove(tempLookupFile)
os.remove(fileLoc)
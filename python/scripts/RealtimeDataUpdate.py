# Author: Glen Adams

import os
import time
import requests
import pandas as pd
import numpy as np
import subprocess
import sqlalchemy
import datetime
import multiprocessing as mp
from datetime import datetime
from io import StringIO

pd.set_option('display.max_columns', None) # DEBUG

# Get DB connection information from environment variables specified by docker-compose.yml
pgServer = os.environ['POSTGRES_SERVER']
pgPort = os.environ['POSTGRES_PORT']
pgUser = os.environ['POSTGRES_USER']
pgPass = os.environ['POSTGRES_PASSWORD']
pgDB = os.environ['POSTGRES_DB']
engine = sqlalchemy.create_engine('postgresql://{pgUser}:{pgPass}@{pgServer}:{pgPort}/{db}'.format(
    pgUser=pgUser, pgPass=pgPass, pgServer=pgServer, pgPort=pgPort, db=pgDB))

# Set relevant constants
url = r"https://waterservices.usgs.gov/nwis/iv/?format=rdb&stateCd=<REPLACEME>&variable=72019&siteType=GW&siteStatus=active&period=P1D"
lookupCoordsURL = r"https://waterdata.usgs.gov/nwis/inventory?search_site_no=<REPLACEME>&search_site_no_match_type=exact&group_key=NONE&format=sitefile_output&sitefile_output_format=rdb&column_name=dec_lat_va&column_name=dec_long_va&list_of_search_criteria=search_site_no"
# states = ["al", "az", "ar", "ca", "co", "ct", "de", "fl", "ga", "id", "il", "in", "ia", "ks", "ky", "la", "me", "md", "ma", "mi", "mn", "ms", "mo", "mt", "ne", "nv", "nh", "nj", "nm", "ny", "nc", "nd", "oh", "ok", "or", "pa", "ri", "sc", "sd", "tn", "tx", "ut", "vt", "va", "wa", "wv", "wi", "wy"]
states = ["md"]
cpus = int(mp.cpu_count() * float(os.environ['PARALLEL_FACTOR'])) # Set number of processes for parallel processing
runeveryx = int(float(os.environ['RUN_INTERVAL_MIN']) * 60) # Allows for decimal values for minutes. Ex. 7.5
full_data = ""

def fix_merge(df_merged):
    for col in df_merged.columns:
        if col == 'lat_y' or col == 'lon_y':
            new_name = col.replace('_y','')
            df_merged.rename(columns = {col : new_name }, inplace=True)
        elif col[-2:] == '_x' and 'lat' not in col and 'lon' not in col:
            new_name = col.replace('_x','')
            df_merged.rename(columns = {col : new_name }, inplace=True)
        elif col[-2:] != '_x' and col[-2:] != '_y':
            pass # this is the field the merge is based on, do nothing
        else:
            df_merged.drop(columns = col, inplace = True)
    return df_merged

def get_coords(site_nos):
    retList = []
    for site_no in site_nos.tolist():
        print("Acquiring coord for {}".format(str(site_no)))
        coordreq = requests.get(lookupCoordsURL.replace("<REPLACEME>", str(site_no))).text.split("\n")
        coordreq = coordreq[len(coordreq) - 2] # last line is blank...
        retList.append([site_no, coordreq.split("\t")[0], coordreq.split("\t")[1]])
    return pd.DataFrame(retList, columns = ['site_no', 'lat', 'lon'])

def mp_get_data(*args):
    state = args[0]
    data = requests.get(url.replace("<REPLACEME>", state)).text
    ret_data = ""
    for line in data.splitlines():
        if (not line.startswith('#') and
            not line.startswith('5s') and
            not line.startswith('agency')): # Remove comments, junk lines and headers from the data
            line = line.strip()
            if line: # Empty strings (blank lines) filtered out
                ret_data += line[:line.find("\tP\t")] + "\n"
    return ret_data

def log_result(result):
    """
        Callback function for parallel processing.
    """
    global full_data
    if result:
        full_data += result

def parallelize_df(data, func):
    global cpus
    data_split = np.array_split(data, cpus)
    pool = mp.Pool(processes=cpus)
    data = pd.concat(pool.map(func, data_split))
    pool.close()
    pool.join()
    return data

def main():
    global full_data
    full_data = "agency\tsite_no\tdatetime\ttz_cd\tdepth_towl_ft\n" # Header
    # Begin requesting and processing, parallelized for speed
    p = mp.Pool(processes=cpus)
    results = []
    print("Acquiring data for each state...")    
    for state in states:
        results.append(p.apply_async(mp_get_data, args = [state], callback = log_result))
    p.close()
    p.join()

    # Set date and acquire known site locations 
    curDate = datetime.today().strftime('%Y-%m-%d')
    try:
        print("Checking for known site locations...")
        knownSites = pd.read_sql("SELECT DISTINCT site_no, ST_X(geom) as lon, ST_Y(geom) as lat from usgs_wl_data" , engine)
    except: 
        knownSites = None # first run, table is not initialized -- no site locations are known

    df = pd.read_table(StringIO(full_data), sep="\t", index_col=False)
    df['depth_towl_ft'] = pd.to_numeric(df.depth_towl_ft, errors='coerce') # Filter out garbage values in the depth column
    df['uid'] = df['site_no'].astype('str') + "_" + df['datetime'].astype('str')
    df['lat'] = np.nan
    df['lon'] = np.nan

    # Get coords from known sites
    try:
        df = fix_merge(df.merge(knownSites, how='left', on='site_no'))
    except:
        pass # Must be the first run

    # Get rows still missing coords
    df_missing = df[df.lon.isna() | df.lat.isna()].drop_duplicates(subset='site_no')

    # Retrieve coordinates from USGS for locations missing coords, parallelized so first run isn't so painful. Only if df_missing isn't empty
    if not df_missing.empty:
        df_missing = fix_merge(df_missing.merge(parallelize_df(df_missing['site_no'], get_coords), how='left', on='site_no'))

        # Update full dataframe with missing coordinates
        df = fix_merge(df.merge(df_missing, how='left', on='site_no', validate="many_to_one"))

    # Insert to DB 
    print("Inserting any new data into DB...")
    df.to_sql('temptable', con=engine, if_exists='replace', index=False) 
    query = """ INSERT INTO usgs_wl_data (uid, agency, site_no, datetime, tz_cd, depth_towl_ft, lat, lon)
                SELECT t.uid, t.agency, t.site_no, TO_TIMESTAMP(t.datetime, 'YYYY-MM-DD HH24:MI:SS'), t.tz_cd, t.depth_towl_ft::DECIMAL, t.lat::DECIMAL, t.lon::DECIMAL
                FROM temptable t
                WHERE NOT EXISTS
                    (SELECT 1 FROM usgs_wl_data f
                    WHERE t.uid = f.uid)"""
    df_query = """ SELECT DISTINCT t.datetime
                    FROM temptable t
                    WHERE NOT EXISTS
                        (SELECT 1 FROM usgs_wl_data f
                        WHERE t.uid = f.uid)"""
    df_contourIntervals = pd.read_sql(df_query, engine) # Create dataframe of unique times that we are inserting first
    engine.execute(query) # Insert new data

    # Adjust df_contourIntervals to round dates to the nearest quarter hour and drop duplicates.
    # Wells do not all report at exactly the same time
    df_contourIntervals['datetime'] = pd.to_datetime(df_contourIntervals['datetime'], format=r'%Y-%m-%d %H:%M:%S')
    df_contourIntervals = (df_contourIntervals['datetime'].dt.round('60min')).drop_duplicates()

    # Create contours using PL\R if new data
    if not df_contourIntervals.empty:
        print("Calculating contours for new data...")
    
        # Append contours to wl_contours table
        print("Inserting new contours to DB...")


if __name__ == "__main__":
    time.sleep(10) # Wait for DB container to be on...
    while True: # Always running, so long as docker container is up.
        main()
        time.sleep(runeveryx)
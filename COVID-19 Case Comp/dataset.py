import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import calendar
import scipy as sp

mobility = pd.read_csv("Datasets/Mobility Data/2020_CA_Region_Mobility_Report.csv")
cases = pd.read_csv("Datasets/conposcovidloc.csv")
datacan = pd.read_csv("Datasets/data_can2.csv")


populations = {
    'Algoma': 118050, 'Durham': 697355, 'Halton': 596369, 'Hamilton': 574263, 'Lambton': 132243, 
    'Middlesex': 506008, 'Niagara': 479183, 'Ottawa': 1028514, 'Peel': 1541994, 'Peterborough': 147890, 
    'Thunder Bay': 151892, 'Toronto': 2965713, 'Waterloo': 595465, 'York': 1181485}
# https://www.citypopulation.de/en/canada/ontario/admin/
areas = {
    'Algoma': 48815, 'Durham': 2524, 'Halton': 964, 'Hamilton': 1138, 'Lambton': 3002, 'Middlesex': 3317,
    'Niagara': 1854, 'Ottawa': 2790, 'Peel': 1247, 'Peterborough': 3769, 'Thunder Bay': 103719,
    'Toronto': 630, 'Waterloo': 1369, 'York': 1762}

REGIONS_OF_INTEREST = list(populations.keys())

def get_weekday(row):
    date = datetime.strptime(row['date'], '%Y-%m-%d')
    return calendar.day_name[date.weekday()]


mobility['weekday'] = mobility.apply(lambda row: get_weekday(row), axis=1)
cols = mobility.columns.tolist()
cols.insert(8, cols.pop())
mobility = mobility[cols]

mobility = mobility.loc[mobility['sub_region_1'] == 'Ontario']
mobility = mobility.loc[mobility['sub_region_2'].notnull()]

mobility = mobility[["sub_region_2", "date", "weekday",
                     "retail_and_recreation_percent_change_from_baseline", 
                     "grocery_and_pharmacy_percent_change_from_baseline", 
                     "parks_percent_change_from_baseline", 
                     "transit_stations_percent_change_from_baseline", 
                     "workplaces_percent_change_from_baseline", 
                     "residential_percent_change_from_baseline"]]
mobility.columns = ['region', 'date', 'weekday', 'retail+rec', 'grocery+pharm', 'parks', 'transit', 'workplaces', 'residential']
mobility = mobility.dropna()
mobility = mobility[mobility['region'].str.contains('|'.join(REGIONS_OF_INTEREST))]

cases = cases[cases['Accurate_Episode_Date'].notna()]
cases = cases[['Accurate_Episode_Date', 'Reporting_PHU']]
cases = cases.dropna()
cases = cases.groupby(cases.columns.tolist(),as_index=False).size()
cases = cases.rename(columns={'Accurate_Episode_Date':'date', 'Reporting_PHU':'region', 'size':'new_cases'})
cases = cases.sort_values(by=['region', 'date'])
cases = cases[cases['region'].str.contains('|'.join(REGIONS_OF_INTEREST))]

for r in REGIONS_OF_INTEREST:
    mobility.loc[mobility['region'].str.contains(r), 'region'] = r
    cases.loc[cases['region'].str.contains(r), 'region'] = r
    
datacan = datacan[['date', 'key_apple_mobility', 'school_closing', 'workplace_closing',
                  'cancel_events', 'gatherings_restrictions', 'transport_closing',
                  'stay_home_restrictions', 'internal_movement_restrictions', 'international_movement_restrictions',
                  'information_campaigns', 'testing_policy', 'contact_tracing', 'stringency_index']]
datacan = datacan[datacan['key_apple_mobility'] == 'Ontario']
datacan = datacan.drop(columns=['key_apple_mobility'])

df = pd.merge(mobility, cases, on=['date', 'region'])
df = pd.merge(df, datacan, on=['date'])
df = df.sort_values(by=['region', 'date']).reset_index(drop=True)
df['population'] = df['region'].map(populations)
df['area'] = df['region'].map(areas)
df['pop_density'] = df['population']/df['area']
df = df[['region','population','area','pop_density','date','weekday','new_cases','retail+rec',
         'grocery+pharm','parks','transit','workplaces','residential','school_closing','workplace_closing',
         'cancel_events','gatherings_restrictions','transport_closing','stay_home_restrictions',
         'internal_movement_restrictions','international_movement_restrictions','information_campaigns',
         'testing_policy','contact_tracing','stringency_index']]

df.to_csv('Datasets/full_data.csv', index=False)

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import calendar
import scipy as sp

mobility = pd.read_csv("Datasets/Mobility Data/2020_CA_Region_Mobility_Report.csv")
cases = pd.read_csv("Datasets/conposcovidloc.csv")
datacan = pd.read_csv("Datasets/data_can2.csv")

start_date = min(mobility['date'])
end_date = max(mobility['date'])
date_list = pd.Series(pd.date_range(start_date, end_date).format())

populations = {
    'Durham': 697355, 'Halton': 596369, 'Hamilton': 574263,
    'Middlesex': 506008, 'Niagara': 479183, 'Ottawa': 1028514, 'Peel': 1541994,
    'Toronto': 2965713, 'Waterloo': 595465, 'York': 1181485}
# https://www.citypopulation.de/en/canada/ontario/admin/
areas = {
    'Durham': 2524, 'Halton': 964, 'Hamilton': 1138, 'Middlesex': 3317,
    'Niagara': 1854, 'Ottawa': 2790, 'Peel': 1247,
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
mobility = mobility[mobility['region'].str.contains('|'.join(REGIONS_OF_INTEREST))]

cases = cases[cases['Accurate_Episode_Date'].notna()]
cases = cases[['Accurate_Episode_Date', 'Reporting_PHU']]
cases = cases.dropna()
cases = cases.groupby(cases.columns.tolist(),as_index=False).size()
cases = cases.rename(columns={'Accurate_Episode_Date':'date', 'Reporting_PHU':'region', 'size':'new_cases'})
cases = cases.sort_values(by=['region', 'date'])
cases = cases[cases['region'].str.contains('|'.join(REGIONS_OF_INTEREST))]

case_list = []
for r in REGIONS_OF_INTEREST:
    mobility.loc[mobility['region'].str.contains(r), 'region'] = r
    cases.loc[cases['region'].str.contains(r), 'region'] = r
    
    c = cases[cases['region']==r]
    c = c.set_index(['date', 'region']).iloc[:,0]
    c2 = pd.DataFrame()
    c2['date'] = date_list
    c2['region'] = r
    c2 = c2.set_index(['date', 'region'])
    c2['new_cases'] = c
    c2 = c2.fillna(0)
    c2 = c2.reset_index()
    case_list.append(c2)
cases = pd.concat(case_list).reset_index(drop=True)

#datacan = datacan[['date', 'key_apple_mobility', 'school_closing', 'workplace_closing',
#                  'cancel_events', 'gatherings_restrictions', 'transport_closing',
#                  'stay_home_restrictions', 'internal_movement_restrictions', 'international_movement_restrictions',
#                  'information_campaigns', 'testing_policy', 'contact_tracing', 'stringency_index']]
#datacan = datacan[datacan['key_apple_mobility'] == 'Ontario']
#datacan = datacan.drop(columns=['key_apple_mobility'])

df = pd.merge(mobility, cases, on=['date', 'region'])
#df = pd.merge(df, datacan, on=['date'], how='outer')
df = df.sort_values(by=['region', 'date']).reset_index(drop=True)
df['population'] = df['region'].map(populations)
df['area'] = df['region'].map(areas)
df['pop_density'] = df['population']/df['area']
df = df[['region','population','area','pop_density','date','weekday','new_cases','retail+rec',
         'grocery+pharm','parks','transit','workplaces','residential']]#,'school_closing','workplace_closing',
         #'cancel_events','gatherings_restrictions','transport_closing','stay_home_restrictions',
         #'internal_movement_restrictions','international_movement_restrictions','information_campaigns',
         #'testing_policy','contact_tracing','stringency_index']]
df = df[df['new_cases'].notna()]

df.to_csv('Datasets/full_data.csv', index=False)


# 7-day simple moving average
df_list = []
for region in REGIONS_OF_INTEREST:
    df_reg = df[df['region']==region]
    df2 = df_reg.copy()
    for i in range(0, df2.shape[0]-6):
        df2.loc[df2.index[i+6], 'new_cases'] = np.round(((df_reg.iloc[i,6] + df_reg.iloc[i+1,6] + df_reg.iloc[i+2,6] + 
                                                          df_reg.iloc[i+3,6] + df_reg.iloc[i+4,6] + df_reg.iloc[i+5,6] + 
                                                          df_reg.iloc[i+6,6])/7), 3)
        df2.loc[df2.index[i+6], 'retail+rec'] = np.round(((df_reg.iloc[i,7] + df_reg.iloc[i+1,7] + df_reg.iloc[i+2,7] + 
                                                          df_reg.iloc[i+3,7] + df_reg.iloc[i+4,7] + df_reg.iloc[i+5,7] + 
                                                          df_reg.iloc[i+6,7])/7), 3)
        df2.loc[df2.index[i+6], 'grocery+pharm'] = np.round(((df_reg.iloc[i,8] + df_reg.iloc[i+1,8] + df_reg.iloc[i+2,8] + 
                                                          df_reg.iloc[i+3,8] + df_reg.iloc[i+4,8] + df_reg.iloc[i+5,8] + 
                                                          df_reg.iloc[i+6,8])/7), 3)
        df2.loc[df2.index[i+6], 'parks'] = np.round(((df_reg.iloc[i,9] + df_reg.iloc[i+1,9] + df_reg.iloc[i+2,9] + 
                                                          df_reg.iloc[i+3,9] + df_reg.iloc[i+4,9] + df_reg.iloc[i+5,9] + 
                                                          df_reg.iloc[i+6,9])/7), 3)
        df2.loc[df2.index[i+6], 'transit'] = np.round(((df_reg.iloc[i,10] + df_reg.iloc[i+1,10] + df_reg.iloc[i+2,10] + 
                                                          df_reg.iloc[i+3,10] + df_reg.iloc[i+4,10] + df_reg.iloc[i+5,10] + 
                                                          df_reg.iloc[i+6,10])/7), 3)
        df2.loc[df2.index[i+6], 'workplaces'] = np.round(((df_reg.iloc[i,11] + df_reg.iloc[i+1,11] + df_reg.iloc[i+2,11] + 
                                                          df_reg.iloc[i+3,11] + df_reg.iloc[i+4,11] + df_reg.iloc[i+5,11] + 
                                                          df_reg.iloc[i+6,11])/7), 3)
        df2.loc[df2.index[i+6], 'residential'] = np.round(((df_reg.iloc[i,12] + df_reg.iloc[i+1,12] + df_reg.iloc[i+2,12] + 
                                                          df_reg.iloc[i+3,12] + df_reg.iloc[i+4,12] + df_reg.iloc[i+5,12] + 
                                                          df_reg.iloc[i+6,12])/7), 3)   
    df2 = df2.reset_index(drop=True).iloc[6:]
    df_list.append(df2)

df2 = pd.concat(df_list)
df2 = df2.reset_index(drop=True)
df2.to_csv('Datasets/full_data_7SMA.csv', index=False)

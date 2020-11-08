import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import calendar
import matplotlib.pyplot as plt

lag = 7
mob_type = 'Toronto'
regions_of_interest = ['Algoma', 'Brant', 'Chatham-Kent', 'Durham', 'Halton',
                       'Hamilton', 'Lambton', 'Middlesex', 'Niagara', 'Ottawa',
                       'Peel', 'Peterborough', 'Waterloo', 'Thunder Bay',
                       'Timiskaming', 'Toronto', 'York']
mobility_types = ['retail+rec', 'grocery+pharm', 'parks', 'transit', 'workplaces', 'residential']
colormap = {'01':'red','02':'red',
            '03':'blue','04':'blue',
            '05':'green','06':'green',
            '07':'yellow','08':'yellow',
            '09':'purple','10':'purple',
            '11':'black','12':'black'}

def get_weekday(row):
    date = datetime.strptime(row['date'], '%Y-%m-%d')
    return calendar.day_name[date.weekday()]

mobility = pd.read_csv("../Datasets/Mobility Data/2020_CA_Region_Mobility_Report.csv")
mobility['weekday'] = mobility.apply(lambda row: get_weekday(row), axis=1)
cols = mobility.columns.tolist()
cols.insert(8, cols.pop())
mobility = mobility[cols]

cases = pd.read_csv("../Datasets/ON regional cases.csv")


def clean_mobility(mobility, region):
    mobility = mobility.loc[mobility['sub_region_1'] == 'Ontario']
    mobility = mobility.loc[mobility['sub_region_2'].notnull()]
    mob_regions = mobility['sub_region_2'].unique()
    mobility = mobility.loc[mobility['sub_region_2'] == next((s for s in mob_regions if region in s), None)]
    mobility = mobility[["date", "weekday",
                        "retail_and_recreation_percent_change_from_baseline", 
                        "grocery_and_pharmacy_percent_change_from_baseline", 
                        "parks_percent_change_from_baseline", 
                        "transit_stations_percent_change_from_baseline", 
                        "workplaces_percent_change_from_baseline", 
                        "residential_percent_change_from_baseline"]]
    mobility.columns = ['date', 'weekday', 'retail+rec', 'grocery+pharm', 'parks', 'transit', 'workplaces', 'residential']
    mobility = mobility.dropna()
    return mobility

def plot_mobility_by_region(mobility, cases, region, mob_type, lag):
    phu_regions = np.sort(cases['Reporting_PHU'].unique())
    cases = cases[['Accurate_Episode_Date', 'Reporting_PHU']]
    cases = cases.dropna()
    cases['Accurate_Episode_Date'] = cases['Accurate_Episode_Date'].str[:-9]
    
    cases = cases.loc[cases["Reporting_PHU"] == next((s for s in phu_regions if region in s), None)]
    dates = cases['Accurate_Episode_Date'].reset_index(drop=True)
    for i in range(0, len(dates)):
        date = dates[i]
        date_str = datetime.strptime(date, '%Y-%m-%d')
        date_str = (date_str - timedelta(days=lag)).strftime('%Y-%m-%d')
        dates[i] = date_str
        
    date_count = dates.value_counts()
    date_count = date_count.sort_index()
    date_count = date_count.to_dict()
    
    date_mob_count = list()
    colours = list()
    for i in mobility['date']:
        month = i[5:7]
        colours.append(colormap[month])
        if i in date_count:
            date_mob_count.append(date_count[i])
        else:
            date_mob_count.append(0)
    date_mob_count = pd.Series(date_mob_count)
    
    mobility = mobility.reset_index(drop=True)
    mobility["case episodes"] = date_mob_count
    
    mobility['colour'] = colours
    
    plt.figure()
    plt.scatter(mobility[mob_type], mobility['case episodes'], color=mobility['colour'])
    plt.title(region)
    plt.xlabel(mob_type)
    plt.ylabel('case episodes')

def compare_regions(mob_type):
    for region in regions_of_interest:
        plot_mobility_by_region(mobility, cases, region, mob_type)
        
def compare_mob_type(region):
    for mob_type in mobility_types:
        plot_mobility_by_region(mobility, cases, region, mob_type)
        
def plot_all():
    for region in regions_of_interest:
        for mob_type in mobility_types:
            plot_mobility_by_region(mobility, cases, region, mob_type)
            
            
hi = mobility.loc[mobility['weekday']=='Monday']

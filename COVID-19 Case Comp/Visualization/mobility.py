import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import calendar
import matplotlib.pyplot as plt
import scipy as sp
from scipy import stats
from scipy.stats import ttest_ind

# How does the relationship between mobility + case counts differ between regions?
# How does the relationship between mobility + case counts differ between mobility types?

REGIONS_OF_INTEREST = ['Algoma', 'Brant', 'Chatham-Kent', 'Durham', 'Halton',
                       'Hamilton', 'Lambton', 'Middlesex', 'Niagara', 'Ottawa',
                       'Peel', 'Peterborough', 'Waterloo', 'Thunder Bay',
                       'Timiskaming', 'Toronto', 'York']

MOBILITY_TYPES = ['retail+rec', 'grocery+pharm', 'parks', 'transit', 'workplaces', 'residential']

COLORMAP = {'01':'tab:blue','02':'tab:orange',
            '03':'tab:green','04':'tab:red',
            '05':'tab:purple','06':'tab:brown',
            '07':'tab:pink','08':'tab:gray',
            '09':'tab:olive','10':'tab:cyan',
            '11':'black','12':'black'}

def get_weekday(row):
    date = datetime.strptime(row['date'], '%Y-%m-%d')
    return calendar.day_name[date.weekday()]

region = 'Toronto'
mob_type = 'retail+rec'
lag = 0

mobility = pd.read_csv("../Datasets/Mobility Data/2020_CA_Region_Mobility_Report.csv")
mobility['weekday'] = mobility.apply(lambda row: get_weekday(row), axis=1)
cols = mobility.columns.tolist()
cols.insert(8, cols.pop())
mobility = mobility[cols]
mobility = mobility.loc[mobility['sub_region_1'] == 'Ontario']
mobility = mobility.loc[mobility['sub_region_2'].notnull()]

cases = pd.read_csv("../Datasets/conposcovidloc.csv")
cases = cases[cases['Accurate_Episode_Date'].notna()]


def remove_month(mobility, cases, month):
    mobility = mobility[~mobility.date.str.contains("2020-"+month)]
    cases = cases[~cases.Accurate_Episode_Date.str.contains("2020-"+month)]
    return mobility, cases
    
'''
mobility, cases = remove_month(mobility, cases, '01')
mobility, cases = remove_month(mobility, cases, '02')
#mobility, cases = remove_month(mobility, cases, '03')
#mobility, cases = remove_month(mobility, cases, '04')
#mobility, cases = remove_month(mobility, cases, '05')
#mobility, cases = remove_month(mobility, cases, '06')
#mobility, cases = remove_month(mobility, cases, '07')
mobility, cases = remove_month(mobility, cases, '08')
mobility, cases = remove_month(mobility, cases, '09')
mobility, cases = remove_month(mobility, cases, '10')
mobility, cases = remove_month(mobility, cases, '11')
mobility, cases = remove_month(mobility, cases, '12')
'''

def to_weekly(mobility, cases, region):
    mobility['date'] = pd.to_datetime(mobility['date']) - pd.to_timedelta(7, unit='d')
    mobility = mobility.groupby(['region', pd.Grouper(key='date', freq='W-MON')])['retail+rec', 
                                                                                               'grocery+pharm',
                                                                                               'parks',
                                                                                               'transit',
                                                                                               'workplaces',
                                                                                               'residential'].mean().reset_index().sort_values('date')
    mobility['date'] = mobility['date'].apply(lambda x: x.strftime('%Y-%m-%d'))
    
    phu_regions = np.sort(cases['Reporting_PHU'].unique())
    cases = cases[['Accurate_Episode_Date', 'Reporting_PHU']]
    cases = cases.loc[cases["Reporting_PHU"] == next((s for s in phu_regions if region in s), None)]
    cases['Accurate_Episode_Date'] = pd.to_datetime(cases['Accurate_Episode_Date']) - pd.to_timedelta(7, unit='d')
    cases['Accurate_Episode_Date'] = cases['Accurate_Episode_Date'].apply(lambda x: x - timedelta(days = x.weekday()))
    cases['Accurate_Episode_Date'] = cases['Accurate_Episode_Date'].apply(lambda x: x.strftime('%Y-%m-%d'))
    return mobility, cases


def plot_mobility_by_region(mobility, cases, region, mob_type, weekly=False):
    mobility = mobility.loc[mobility['sub_region_2'] == next((s for s in mobility['sub_region_2'].unique() if region in s), None)]
    mobility = mobility[["sub_region_2", "date", "weekday",
                     "retail_and_recreation_percent_change_from_baseline", 
                     "grocery_and_pharmacy_percent_change_from_baseline", 
                     "parks_percent_change_from_baseline", 
                     "transit_stations_percent_change_from_baseline", 
                     "workplaces_percent_change_from_baseline", 
                     "residential_percent_change_from_baseline"]]
    mobility.columns = ['region', 'date', 'weekday', 'retail+rec', 'grocery+pharm', 'parks', 'transit', 'workplaces', 'residential']
    mobility = mobility.dropna()

    phu_regions = np.sort(cases['Reporting_PHU'].unique())
    cases = cases[['Accurate_Episode_Date', 'Reporting_PHU']]
    cases = cases.dropna()
    #cases['Accurate_Episode_Date'] = cases['Accurate_Episode_Date'].str[:-9]
    
    cases = cases.loc[cases["Reporting_PHU"] == next((s for s in phu_regions if region in s), None)]
    
    if weekly:
        mobility, cases = to_weekly(mobility, cases, 'Toronto')

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
        colours.append(COLORMAP[month])
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
    plt.xlabel(mob_type)
    plt.ylabel('case episodes')
    linreg = sp.stats.linregress(mobility[mob_type], mobility['case episodes'])
    rvalue = round(linreg.rvalue, 2)
    plt.title(region + ": " + str(rvalue))    
    print(mob_type, rvalue)

def compare_regions(mob_type):
    for region in REGIONS_OF_INTEREST:
        plot_mobility_by_region(mobility, cases, region, mob_type)
        
def compare_mob_type(region):
    for mob_type in MOBILITY_TYPES:
        plot_mobility_by_region(mobility, cases, region, mob_type)
        
def plot_all():
    for region in REGIONS_OF_INTEREST:
        for mob_type in MOBILITY_TYPES:
            plot_mobility_by_region(mobility, cases, region, mob_type)

compare_mob_type('Toronto')








# Is there a significant difference in mobility + mobility types between weekdays/weekends?
    # question: how does google define "workplace"? is walmart a retail+rec and not a workplace?

mobility = mobility.loc[mobility['sub_region_2'] == next((s for s in mobility['sub_region_2'].unique() if region in s), None)]
mobility = mobility[["date", "weekday",
                     "retail_and_recreation_percent_change_from_baseline", 
                     "grocery_and_pharmacy_percent_change_from_baseline", 
                     "parks_percent_change_from_baseline", 
                     "transit_stations_percent_change_from_baseline", 
                     "workplaces_percent_change_from_baseline", 
                     "residential_percent_change_from_baseline"]]
mobility.columns = ['date', 'weekday', 'retail+rec', 'grocery+pharm', 'parks', 'transit', 'workplaces', 'residential']
mobility = mobility.dropna()

weekdays_mean = {}
weekends_mean = {}
for mob_type in MOBILITY_TYPES:
    weekdays = mobility.loc[(mobility['weekday']=='Monday') | (mobility['weekday']=='Tuesday') 
                            | (mobility['weekday']=='Wednesday') | (mobility['weekday']=='Thursday')
                            | (mobility['weekday']=='Friday')]
    weekdays = weekdays[mob_type]
    mean = weekdays.mean()
    weekdays_mean[mob_type] = mean
    
    weekends = mobility.loc[(mobility['weekday']=='Saturday') | (mobility['weekday']=='Sunday')]
    weekends = weekends[mob_type]
    mean = weekends.mean()
    weekends_mean[mob_type] = mean
    
    stat, p = ttest_ind(weekdays, weekends)
    print('stat=%.3f, p=%.3f' % (stat, p))
    
    

# Is there a significant difference in case counts between weekdays/weekends?

phu_regions = np.sort(cases['Reporting_PHU'].unique())
cases = cases[['Accurate_Episode_Date', 'Reporting_PHU']]
cases = cases.dropna()
cases['Accurate_Episode_Date'] = cases['Accurate_Episode_Date'].str[:-9]
cases = cases.loc[cases["Reporting_PHU"] == next((s for s in phu_regions if region in s), None)]
cases = cases.rename(columns = {'Accurate_Episode_Date':'date'})
cases['weekday'] = cases.apply(lambda row: get_weekday(row), axis=1)
dates = cases['weekday'].reset_index(drop=True)
date_count = dates.value_counts()
date_count = date_count.sort_index()
date_count = date_count.to_dict()

# More questions:
    # Adjust lag to see if my hypothesis is right that case counts are actually affecting mobility
        #look at effect of mobility on the derivative of cases?
    
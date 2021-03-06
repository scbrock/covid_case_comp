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

df = pd.read_csv('../Datasets/full_data_7SMA.csv')
#df = pd.read_csv('../Datasets/full_data.csv')

REGIONS_OF_INTEREST = ['Durham', 'Halton', 'Hamilton', 'Middlesex', 'Niagara', 'Ottawa',
                       'Peel', 'Waterloo', 'Toronto', 'York']

MOBILITY_TYPES = ['retail+rec', 'grocery+pharm', 'parks', 'transit', 'workplaces', 'residential']

COLORMAP = {'02':'tab:blue','03':'tab:orange',
            '04':'tab:green','05':'tab:red',
            '06':'tab:purple','07':'tab:brown',
            '08':'tab:pink','09':'tab:gray',
            '10':'tab:olive','11':'tab:cyan',
            '12':'black'}

region = 'Toronto'
mob_type = 'retail+rec'
lag = 7

def condense_df(df):
    df = df[['region', 'pop_density', 'date', 'weekday', 'new_cases', 'retail+rec',
             'grocery+pharm', 'parks', 'transit', 'workplaces', 'residential']]
    return df

df = condense_df(df)


def remove_month(df, month):
    df = df[~df.date.str.contains("2020-"+month)]
    return df
    
'''
df = remove_month(df, '01')
df = remove_month(df, '02')
df = remove_month(df, '03')
df = remove_month(df, '04')
df = remove_month(df, '05')
df = remove_month(df, '06')
df = remove_month(df, '07')
df = remove_month(df, '08')
df = remove_month(df, '09')
df = remove_month(df, '10')
df = remove_month(df, '11')
df = remove_month(df, '12')
'''

def to_weekly(df):
    df['date'] = pd.to_datetime(df['date']) - pd.to_timedelta(7, unit='d')
    df = df.groupby(['region', pd.Grouper(key='date', freq='W-MON')])['pop_density', 'new_cases', 'retail+rec', 'grocery+pharm', 'parks', 
                                                                      'transit', 'workplaces', 'residential'].mean().reset_index().sort_values(['region', 'date'])
    df['date'] = df['date'].apply(lambda x: x.strftime('%Y-%m-%d'))
    
    return df


def plot_mobility_by_region(df, region, mob_type, weekly=False):
    if weekly:
        df = to_weekly(df)
    
    def apply_lag(row, lag):
        print(row)
        date_str = datetime.strptime(row['date'], '%Y-%m-%d')
        date_str = (date_str + timedelta(days=lag)).strftime('%Y-%m-%d')
        return date_str
        
    df = df.loc[df['region'] == region]
    df['date_2'] = df.apply(lambda row: apply_lag(row, lag), axis=1)
    dates = df['date'].tolist()
    new_cases_2 = []
    for date in df['date_2'].tolist():
        if date not in dates:
            new_cases_2.append(None)
        else:
            new_cases_2.append(df.loc[df['date']==date, 'new_cases'].to_string(index=False)[1:])
    for i in range(0, len(new_cases_2)-1):
        if new_cases_2[i] is not None:
            new_cases_2[i] = float(new_cases_2[i])
            
    df = df.reset_index()
    df['new_cases_2'] = pd.Series(new_cases_2)
    df = df.replace(to_replace='None', value=np.nan).dropna()
    
    colours = list()
    for i in df['date']:
        month = i[5:7]
        colours.append(COLORMAP[month])
    df['colour'] = colours
    
    plt.figure()
    plt.scatter(df[mob_type], df['new_cases_2'], color=df['colour'])
    plt.xlabel(mob_type)
    plt.ylabel('new_cases, ' + str(lag) + ' day lag')
    linreg = sp.stats.linregress(df[mob_type], df['new_cases'])
    rvalue = round(linreg.rvalue, 2)
    plt.title(region + ": " + str(rvalue))    
    print(mob_type, rvalue)

def compare_regions(mob_type):
    for region in REGIONS_OF_INTEREST:
        plot_mobility_by_region(df, region, mob_type)
        
def compare_mob_type(region):
    for mob_type in MOBILITY_TYPES:
        plot_mobility_by_region(df, region, mob_type)
        
def plot_all():
    for region in REGIONS_OF_INTEREST:
        for mob_type in MOBILITY_TYPES:
            plot_mobility_by_region(df, region, mob_type)

# compare_mob_type('Toronto')
# compare_regions('retail+rec')





# Is there a significant difference in mobility + mobility types, and case counts
# between weekdays/weekends?
    # question: how does google define "workplace"? is walmart a retail+rec and not a workplace?
def weekdays_vs_weekends(df, region):
    df = df.loc[df['region'] == region]
    
    weekdays_mean = {}
    weekends_mean = {}
    for mob_type in MOBILITY_TYPES:
        weekdays = df.loc[(df['weekday']=='Monday') | (df['weekday']=='Tuesday') 
                                | (df['weekday']=='Wednesday') | (df['weekday']=='Thursday')
                                | (df['weekday']=='Friday')]
        weekdays = weekdays[mob_type]
        mean = weekdays.mean()
        weekdays_mean[mob_type] = mean
        
        weekends = df.loc[(df['weekday']=='Saturday') | (df['weekday']=='Sunday')]
        weekends = weekends[mob_type]
        mean = weekends.mean()
        weekends_mean[mob_type] = mean
        
        stat, p = ttest_ind(weekdays, weekends)
        print('mobility difference - ' + str(mob_type) + ': stat=%.3f, p=%.3f' % (stat, p))
    
    days = df.groupby(['weekday']).agg({'new_cases': 'sum'})

    return weekdays_mean, weekends_mean, days

# mob_weekdays_mean, mob_weekends_mean, days = weekdays_vs_weekends(df, 'Toronto')
    
# More questions:
    # Adjust lag to see if my hypothesis is right that case counts are actually affecting mobility
        #look at effect of mobility on the derivative of cases?
        
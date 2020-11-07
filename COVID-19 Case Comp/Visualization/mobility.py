import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# mobility effect on cases (accurate episodic date, not reporting date)

MOB_CSV = pd.read_csv("../Datasets/Mobility Data/2020_CA_Region_Mobility_Report.csv")
CASES_CSV = pd.read_csv("../Datasets/ON regional cases.csv")

REGIONS_OF_INTEREST = ['Algoma', 'Brant', 'Chatham-Kent', 'Durham', 'Halton',
                       'Hamilton', 'Lambton', 'Middlesex', 'Niagara', 'Ottawa',
                       'Peel', 'Peterborough', 'Waterloo', 'Thunder Bay',
                       'Timiskaming', 'Toronto', 'York']

MOBILITY_TYPES = ['retail+rec', 'grocery+pharm', 'parks', 'transit', 'workplaces', 'residential']

COLORMAP = {'01':'red',
            '02':'red',
            '03':'blue',
            '04':'blue',
            '05':'green',
            '06':'green',
            '07':'yellow',
            '08':'yellow',
            '09':'purple',
            '10':'purple',
            '11':'black',
            '12':'black'}
        
def plot_mobility_by_region(mobility, cases, region, mob_type):
    mobility = mobility.loc[mobility['sub_region_1'] == 'Ontario']
    mobility = mobility.loc[mobility['sub_region_2'].notnull()]
    mob_regions = mobility['sub_region_2'].unique()
    mobility = mobility.loc[mobility['sub_region_2'] == next((s for s in mob_regions if region in s), None)]
    mobility = mobility[["date", 
                        "retail_and_recreation_percent_change_from_baseline", 
                        "grocery_and_pharmacy_percent_change_from_baseline", 
                        "parks_percent_change_from_baseline", 
                        "transit_stations_percent_change_from_baseline", 
                        "workplaces_percent_change_from_baseline", 
                        "residential_percent_change_from_baseline"]]
    mobility.columns = ['date', 'retail+rec', 'grocery+pharm', 'parks', 'transit', 'workplaces', 'residential']
    mobility = mobility.dropna()
    
    phu_regions = np.sort(cases['Reporting_PHU'].unique())
    cases = cases[['Accurate_Episode_Date', 'Reporting_PHU']]
    cases = cases.dropna()
    cases['Accurate_Episode_Date'] = cases['Accurate_Episode_Date'].str[:-9]
    
    cases = cases.loc[cases["Reporting_PHU"] == next((s for s in phu_regions if region in s), None)]
    dates = cases['Accurate_Episode_Date']
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
    plt.title(region)
    plt.xlabel(mob_type)
    plt.ylabel('case episodes')

def compare_regions(mob_type):
    for reg in REGIONS_OF_INTEREST:
        plot_mobility_by_region(MOB_CSV, CASES_CSV, reg, mob_type)
        
def compare_mob_type(reg):
    for mob_type in MOBILITY_TYPES:
        plot_mobility_by_region(MOB_CSV, CASES_CSV, reg, mob_type)
        
def plot_all():
    for reg in REGIONS_OF_INTEREST:
        for mob_type in MOBILITY_TYPES:
            plot_mobility_by_region(MOB_CSV, CASES_CSV, reg, mob_type)

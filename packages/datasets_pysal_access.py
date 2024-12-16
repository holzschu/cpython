import os
import sys
import requests

import pandas as pd


class Datasets(object):
    _dir = 'chi_med_data'

    _homedir = os.path.expanduser("~")
    if (sys.platform == "darwin" and os.uname().machine.startswith("iP")):
        _homedir = os.path.expanduser("~/Documents")

    _dir_path = os.path.join(_homedir, _dir)

    _bucket_url = 'https://uchicago-csds-access.s3.amazonaws.com/ex_datasets'

    _datasets = {'chi_times': 'chicago_metro_times.csv.bz2',
                 'chi_doc': 'chicago_metro_docs_dentists.csv',
                 'chi_pop': 'chicago_metro_pop.csv',
                 'chi_doc_geom': 'chicago_metro_docs_dentists.geojson',
                 'chi_pop_geom': 'chicago_metro_pop.geojson',
                 'chi_euclidean': 'chicago_metro_euclidean_costs.csv.bz2',
                 'chi_euclidean_neighbors': 'chicago_metro_euclidean_cost_neighbors.csv.bz2',
                 'cook_county_hospitals': 'cook_county_hospitals.csv',
                 'cook_county_hospitals_geom': 'hospitals_cookcty.geojson',
                 'cook_county_tracts': 'cook_county_tracts.geojson'}


    @staticmethod
    def load_data(key):
        """
        Return path for available datasets.
        """
        if not os.path.exists(Datasets._dir_path):
            os.mkdir(Datasets._dir_path)
            print('Creating directory chi_med_data...')

        if key not in Datasets._datasets.keys():
            print('{key} not an available dataset. Use Datasets.available_datasets to see the available datasets.'.format(key=key))


        else:

            path = os.path.join(Datasets._dir_path, Datasets._datasets[key])

            if key in Datasets._datasets.keys() and not os.path.exists(path):
                print('Downloading {key} to {path}...'.format(key = key, path = Datasets._dir_path))
                req = requests.get(os.path.join(Datasets._bucket_url, Datasets._datasets[key]))
                file_path = os.path.join(Datasets._dir_path, Datasets._datasets[key])

                with open(file_path, 'wb') as f:
                    f.write(req.content)
                print('Download complete.')

            if '.geojson' in path:
                import geopandas as gpd

                return gpd.read_file(path)


            return pd.read_csv(path)


    @staticmethod
    def available_datasets():
        desc =  '''
chi_times: Cost matrix with travel times from each Chicago Census Tract to all others.\n
chi_doc: Doctor and dentist counts for each Chicago Census Tract.\n
chi_pop: Population counts for each Chicago Census Tract.\n
chi_doc_geom: Doctor and dentist counts for each Chicago Census Tract along with geometric representations for Census Tracts.\n
chi_pop_geom: Population counts for each Chicago Census Tract along with geometric representations for Census Tracts.\n
chi_euclidean: Euclidean distance cost matrix with distances from each demand Chicago Census Tract to all others.\n
chi_euclidean_neighbors: Euclidean distance cost matrix with distances from each supply Census Tract to all others.\n
cook_county_hospitals: Contains data for each hospital location in Cook County including X Y coordinates.\n
cook_county_hospitals_geom: Contains data for each hospital location in Cook County including X Y coordinates, and geometric points for each hospital.\n
cook_county_tracts: Geometric representation of each Census Tract in Cook County.
        '''
        print(desc)

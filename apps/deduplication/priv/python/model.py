import numpy as np
import pandas as pd
import pickle

from sklearn.preprocessing import StandardScaler

from erlport.erlterms import Atom


def weight(python_model,
           d_first_name_woe,
           d_last_name_woe,
           d_second_name_woe,
           d_documents_woe,
           docs_same_number_woe,
           birth_settlement_substr_woe,
           d_tax_id_woe,
           authentication_methods_flag_woe,
           residence_settlement_flag_woe,
           registration_address_settlement_flag_woe,
           gender_flag_woe,
           twins_flag_woe):

    loaded_model = pickle.loads(python_model)

    np_array = np.array([[d_first_name_woe,
                          d_last_name_woe,
                          d_second_name_woe,
                          d_documents_woe,
                          docs_same_number_woe,
                          birth_settlement_substr_woe,
                          d_tax_id_woe,
                          authentication_methods_flag_woe,
                          residence_settlement_flag_woe,
                          registration_address_settlement_flag_woe,
                          gender_flag_woe,
                          twins_flag_woe]])

    predictions = loaded_model.predict_proba(np_array)

    res = np.round(predictions[0][1], 5)

    return Atom(b'ok'), res.item()

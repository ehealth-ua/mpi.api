import numpy as np
import pandas as pd
import pickle

from erlport.erlterms import Atom


def weight(d_first_name_bin,
           d_last_name_bin,
           d_second_name_bin,
           d_documents_bin,
           docs_same_number_bin,
           birth_settlement_substr_bin,
           d_tax_id_bin,
           authentication_methods_flag_bin,
           residence_settlement_flag_bin,
           gender_flag_bin,
           twins_flag_bin,
           woe_dictionary,
           model):
    woes = pickle.loads(woe_dictionary)

    np_array = get_nparray(d_first_name_bin,
                           d_last_name_bin,
                           d_second_name_bin,
                           d_documents_bin.decode("utf-8"),
                           docs_same_number_bin.decode("utf-8"),
                           birth_settlement_substr_bin,
                           d_tax_id_bin,
                           authentication_methods_flag_bin,
                           residence_settlement_flag_bin,
                           gender_flag_bin,
                           twins_flag_bin,
                           woes)

    model = pickle.loads(model)

    predictions = model.predict_proba(np_array)
    res = np.round(predictions[0][1], 5)

    return Atom(b'ok'), res.item()


def get_nparray(d_first_name_bin,
                d_last_name_bin,
                d_second_name_bin,
                d_documents_bin,
                docs_same_number_bin,
                birth_settlement_substr_bin,
                d_tax_id_bin,
                authentication_methods_flag_bin,
                residence_settlement_flag_bin,
                gender_flag_bin,
                twins_flag_bin,
                woes):

    np_array = np.array([[woes['d_first_name_bin'][d_first_name_bin],
                          woes['d_last_name_bin'][d_last_name_bin],
                          woes['d_second_name_bin'][d_second_name_bin],
                          woes['d_documents_bin'][d_documents_bin],
                          woes['docs_same_number_bin'][docs_same_number_bin],
                          woes['birth_settlement_substr_bin'][birth_settlement_substr_bin],
                          woes['d_tax_id_bin'][d_tax_id_bin],
                          woes['authentication_methods_flag_bin'][authentication_methods_flag_bin],
                          woes['residence_settlement_flag_bin'][residence_settlement_flag_bin],
                          woes['gender_flag_bin'][gender_flag_bin],
                          woes['twins_flag_bin'][twins_flag_bin]]])

    return np_array

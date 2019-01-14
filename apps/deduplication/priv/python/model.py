import numpy as np
import pandas as pd
import pickle

from erlport.erlterms import Atom


def weight(bin_list, woe_dict_bin, model_bin):
    woe_dict = pickle.loads(woe_dict_bin)
    woes = bin_to_woe(bin_list, woe_dict)
    np_array = get_nparray(woes)

    model = pickle.loads(model_bin)

    predictions = model.predict_proba(np_array)
    res = np.round(predictions[0][1], 5)

    return Atom(b'ok'), res.item()


def bin_to_woe(bin_list, woe_dict):
    res = dict()

    for atom, val in bin_list:
        bin_key = atom.decode("utf-8")
        if bin_key in woe_dict:
            woe_key = bin_key.replace("bin", "woe")
            res[woe_key] = woe_dict.get(bin_key).get(val)

    return res


def get_nparray(woes):
    np_array = np.array([[woes['d_first_name_woe'],
                          woes['d_last_name_woe'],
                          woes['d_second_name_woe'],
                          woes['d_documents_woe'],
                          woes['docs_same_number_woe'],
                          woes['birth_settlement_substr_woe'],
                          woes['d_tax_id_woe'],
                          woes['authentication_methods_flag_woe'],
                          woes['residence_settlement_flag_woe'],
                          woes['gender_flag_woe'],
                          woes['twins_flag_woe']]])
    return np_array

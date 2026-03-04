#!/bin/sh
#
# This script installs the pre-requisites to prepare the lineage scenarios
#
python --version
pip --version
pip install --upgrade pip
pip install -r requirements.txt

# Generate a demo.xlsx file which could be used to create the custom lineage
# then you feed the demo.xlsx update-lineage sheet with your configuration
# and run the python code below to create the custom lineage in your Fabric account
# python -m pyapacheatlas --make-template ./demo.xlsx

# import json

# from azure.identity import DefaultAzureCredential
# from pyapacheatlas.core import PurviewClient

# cred = DefaultAzureCredential()

# client = PurviewClient(
#     account_name="[PURVIEW_ACCOUNT_NAME]",
#     authentication=cred
# )

# from pyapacheatlas.readers.excel import ExcelConfiguration, ExcelReader

# ec = ExcelConfiguration()
# reader = ExcelReader(ec)

# process = reader.parse_update_lineage("./demo.xlsx")
# results = client.upload_entities(process)


# To run the lineage.py script to create a custom lineage in your Fabric account
# python lineage.py

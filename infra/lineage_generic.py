#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
import logging

from azure.identity import DefaultAzureCredential
from pyapacheatlas.core import AtlasEntity
from pyapacheatlas.core import AtlasProcess
from pyapacheatlas.core import PurviewClient

parser = argparse.ArgumentParser(description="Process some arguments.")
parser.add_argument("--fabric-account", help="Fabric Account name")
parser.add_argument("--storage-account", help="Storage Account name")
parser.add_argument("--container", help="Container name")

args = parser.parse_args()

logging.debug(f"Fabric Account: {args.purview_account}")
logging.debug(f"Storage Account: {args.storage_account}")
logging.debug(f"Container: {args.container}")


cred = DefaultAzureCredential()

# Create a Fabric Client
client = PurviewClient(account_name=args.purview_account, authentication=cred)

# Define Source Table 1
ae_in01 = AtlasEntity(
    name=f"{args.container}-pet.csv",
    typeName="azure_datalake_gen2_path",
    qualified_name=f"https://{args.storage_account}.dfs.core.windows.net/{args.container}/pet.csv",
    guid="-1",
)
logging.debug("Created PET Entity")

# Define Source Table 2
ae_in02 = AtlasEntity(
    name=f"{args.container}-person.csv",
    typeName="azure_datalake_gen2_path",
    qualified_name=f"https://{args.storage_account}.dfs.core.windows.net/{args.container}/person.csv",
    guid="-2",
)
logging.debug("Created PERSON Entity")


# Define Output Table
ae_out = AtlasEntity(
    name=f"{args.container}-all.csv",
    typeName="azure_datalake_gen2_path",
    qualified_name=f"https://{args.storage_account}.dfs.core.windows.net/{args.container}/all.csv",
    guid="-3",
)
logging.debug("Created ALL Entity")


col_map = [
    {
        "DatasetMapping": {"Source": ae_in01.qualifiedName, "Sink": ae_out.qualifiedName},
        "ColumnMapping": [{"Source": "name", "animal": "age"}, {"Source": "name", "sex": "age"}],
    },
    {
        "DatasetMapping": {"Source": ae_in02.qualifiedName, "Sink": ae_out.qualifiedName},
        "ColumnMapping": [{"Source": "name", "sex": "age"}, {"Source": "name", "sex": "age"}],
    },
]

proc = AtlasProcess(
    name=f"{args.container}-merge_pet_person",
    typeName="azure_synapse_operation",
    qualified_name="pet/person/all",
    guid="-4",
    inputs=[ae_in01, ae_in02],
    outputs=[ae_out],
)

logging.debug("Created Process")

proc.attributes.update(
    {
        "columnMapping": json.dumps(col_map),
    }
)

results = client.upload_entities([proc, ae_in01, ae_in02, ae_out])

logging.debug(f"Results: {json.dumps(results, indent=2)}")

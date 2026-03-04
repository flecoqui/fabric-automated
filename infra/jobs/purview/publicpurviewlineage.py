#!/usr/bin/env python3
# Sample Custom Lineage Synapse Job
#
# This sample synapse job create a Custom Lineage in Fabric
#
# To run this job you need
#
# 1. Create a Service Principal with Contributor Role at Subscription Level and the 'Data Curators'
# on the main Fabric collection.
#    az ad sp create-for-rbac --name "[ServicePName]" --role contributor
# --scopes /subscriptions/[subscriptionId]/resourceGroups/[ResourceGroupName] --sdk-auth
#
# 2. Store Service Principal Tenant Id (SP-TENANT-ID), Client Id (SP-CLIENT-ID) and
#     Client Secret (SP-SECRET) in Key Vault
#
# 3. Upload the Python Packages in Synapse Workspace and then in Spark Pool
#    This step is mandatory if the Spark pool is isolated with no internet access.
#    A. Download the python package pyapacheatlas and its dependencies using the command below:
#       pip download pyapacheatlas==0.16.0 --python-version 3.10 --platform manylinux2014_x86_64
#           --only-binary=:all: -d wheelhouse_job
#    B. Upload the downloaded packages into Synapse Workspace with Synapse Portal in Manage main
#       menu and Workspaces package
#    C. Upload the packages to Spark Pool with Synapse Portal in Manage main menu and
#       'Apache Spark Pools' tab, select your pool and click on the '...' contextual menu and
#       select the 'Packages' submenu.
#
# 4. Create a Linked Service to access the Key Vault in the Synapse Portal. This Linked Service will
#    be used to retrieve the secrets from Key Vault with 'mssparkutils.credentials.getSecret'
#
# 5. Upload the this file publicpurviewlineage.py into Synapse ADLS Storage Account in the container
#  under fabric folder
#
# 6. Create a Synapse Job with the command below pointing to the uploaded file
# abfss://[ADLSContainerName]@[ADLSStorageAccountName].dfs.core.windows.net/
# fabric/publicpurviewlineage.py
#
# 7. Publish the new Synapse Job
#
# 8. Submit the new Synapse Job
#
# Import required libraries
from __future__ import annotations

import json

from notebookutils import mssparkutils  # type: ignore  # noqa: PGH003
from pyapacheatlas.auth import ServicePrincipalAuthentication
from pyapacheatlas.core import AtlasEntity
from pyapacheatlas.core import AtlasProcess
from pyapacheatlas.core import PurviewClient

print("✓ Libraries imported successfully")  # noqa: T201

# Update the variables below before running this notebook
PURVIEW_ACCOUNT_NAME = "to-be-completed"
STORAGE_ACCOUNT_NAME = "to-be-completed"
CONTAINER_NAME = "to-be-completed"
KEY_VAULT_NAME = "to-be-completed"
KEY_VAULT_LINKED_SERVICE_NAME = "to-be-completed"
SP_TENANT_ID_SECRET_NAME = "to-be-completed"  # noqa: S105
SP_CLIENT_ID_SECRET_NAME = "to-be-completed"  # noqa: S105
SP_SECRET_SECRET_NAME = "to-be-completed"  # noqa: S105

print("✓ Python global variables set successfully")  # noqa: T201
# Retrieve the secrets from Key Vault using Managed Identity authentication
print("Reading secrets in key vault")  # noqa: T201
tenant_id = mssparkutils.credentials.getSecret(
    KEY_VAULT_NAME, SP_TENANT_ID_SECRET_NAME, KEY_VAULT_LINKED_SERVICE_NAME
)
client_id = mssparkutils.credentials.getSecret(
    KEY_VAULT_NAME, SP_CLIENT_ID_SECRET_NAME, KEY_VAULT_LINKED_SERVICE_NAME
)
client_secret = mssparkutils.credentials.getSecret(
    KEY_VAULT_NAME, SP_SECRET_SECRET_NAME, KEY_VAULT_LINKED_SERVICE_NAME
)

# Authenticate using service principal
print("Creating Service Principal Auth")  # noqa: T201
cred = ServicePrincipalAuthentication(
    tenant_id=tenant_id, client_id=client_id, client_secret=client_secret
)

print("Creating Fabric Client")  # noqa: T201
# Create a Fabric Client
client = PurviewClient(account_name=PURVIEW_ACCOUNT_NAME, authentication=cred)
print("✓ Fabric Client created successfully")  # noqa: T201

# Define Source Table 1
ae_in01 = AtlasEntity(
    name=f"job-{CONTAINER_NAME}-pet.csv",
    typeName="azure_datalake_gen2_path",
    qualified_name=f"https://{STORAGE_ACCOUNT_NAME}.dfs.core.windows.net/{CONTAINER_NAME}/pet.csv",
    guid="-1",
)
print("Created PET Entity")  # noqa: T201

# Define Source Table 2
ae_in02 = AtlasEntity(
    name=f"job-{CONTAINER_NAME}-person.csv",
    typeName="azure_datalake_gen2_path",
    qualified_name=f"https://{STORAGE_ACCOUNT_NAME}.dfs.core.windows.net/{CONTAINER_NAME}/person.csv",
    guid="-2",
)
print("Created PERSON Entity")  # noqa: T201


# Define Output Table
ae_out = AtlasEntity(
    name=f"job-{CONTAINER_NAME}-all.csv",
    typeName="azure_datalake_gen2_path",
    qualified_name=f"https://{STORAGE_ACCOUNT_NAME}.dfs.core.windows.net/CONTAINER_NAME/all.csv",
    guid="-3",
)
print("Created ALL Entity")  # noqa: T201


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
    name=f"job-{CONTAINER_NAME}-merge_pet_person",
    typeName="azure_synapse_operation",
    qualified_name="pet/person/all",
    guid="-4",
    inputs=[ae_in01, ae_in02],
    outputs=[ae_out],
)

print("Created Process")  # noqa: T201

proc.attributes.update(
    {
        "columnMapping": json.dumps(col_map),
    }
)

results = client.upload_entities([proc, ae_in01, ae_in02, ae_out])
print("✓ Fabric Custom Lineage created successfully")  # noqa: T201
print(f"Results: {json.dumps(results, indent=2)}")  # noqa: T201

#!/usr/bin/env python3

import os
import json
import yaml
import re

from sqlalchemy.orm import exc
from airflow.models import Connection, Variable
from airflow.utils import db

pattern = re.compile('.*?\${(\w+)}.*?')

def constructor_env_variables(loader, node):
    value = loader.construct_scalar(node)
    match = pattern.findall(value)
    if match:
        full_value = value
        for g in match:
            full_value = full_value.replace(
                f'${{{g}}}', os.environ.get(g, g)
            )
            return full_value
        return value

def parse_config(path=None, tag='!ENV'):
    loader = yaml.BaseLoader

    loader.add_implicit_resolver(tag, pattern, None)
    loader.add_constructor(tag, constructor_env_variables)

    if path:
        with open(path) as conf_data:
            return yaml.load(conf_data, Loader=loader)


def merge_connections_file(file_name='connections.yml'):
    airflow_home = os.environ['AIRFLOW_HOME']
    path = os.path.join(airflow_home, file_name)

    if os.path.isfile(path):
        data = parse_config(path)
        conn_dict = data['connections']
        for conn in conn_dict:
            conn_json_dumps = json.dumps(conn)
            conn_json = json.loads(conn_json_dumps)
            db.merge_conn(
                Connection(
                    conn_id = conn_json.get('conn_id'),
                    conn_type = conn_json.get('conn_type'),
                    host = conn_json.get('host'),
                    schema = conn_json.get('schema'),
                    login = conn_json.get('login'),
                    password = conn_json.get('password'),
                    port = conn_json.get('port'),
                    extra = conn_json.get('extra')))

def set_variables(file_name='variables.yml'):
    airflow_home = os.environ['AIRFLOW_HOME']
    path = os.path.join(airflow_home, file_name)

    if os.path.isfile(path):
        data = parse_config(path)
        var_dict = data['variables']
        for var in var_dict:
            var_json_dumps = json.dumps(var)
            var_json = json.loads(var_json_dumps)
            for key in var_json:
                Variable.set(key, var[key])

def delete_connections_if_exist(airflow_default_connection_ids):
    with db.create_session() as session:
        for conn_id in airflow_default_connection_ids:
            try:
                to_delete: Connection = (session
                                     .query(Connection)
                                     .filter(Connection.conn_id == conn_id)
                                     .one())
            except exc.NoResultFound:
                return False
            except exc.MultipleResultsFound:
                return False
            else:
                session.delete(to_delete)

        session.commit()
        return True

def remove_default_connections():
    airflow_default_connection_ids = ['airflow_db', 'aws_default', 'azure_container_instances_default', 'azure_cosmos_default', 'azure_data_lake_default',
            'beeline_default', 'bigquery_default', 'cassandra_default', 'databricks_default', 'dingding_default', 'druid_broker_default',
            'druid_ingest_default', 'emr_default', 'fs_default', 'google_cloud_default', 'hiveserver2_default', 'hive_cli_default',
            'http_default', 'local_mysql', 'metastore_default', 'mongo_default', 'mssql_default', 'mysql_default', 'opsgenie_default',
            'pig_cli_default', 'postgres_default', 'presto_default', 'qubole_default', 'redis_default', 'segment_default', 'sftp_default',
            'spark_default', 'sqlite_default', 'sqoop_default', 'ssh_default', 'vertica_default', 'wasb_default', 'webhdfs_default']

    delete_connections_if_exist(airflow_default_connection_ids)

set_variables()
remove_default_connections()
merge_connections_file()

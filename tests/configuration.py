import pytest
import sys

from airflow.configuration import AirflowConfigParser
from airflow.exceptions import AirflowConfigException

AIRFLOW_CONFIG = 'airflow.cfg'

def test_configuration_file():
    """
    Test configuration file basic errors
    """

    try:
        conf = AirflowConfigParser()
        conf.read(AIRFLOW_CONFIG)
        #conf._validate()
        #conf._validate_config_dependencies()
        #assert conf.is_validated == True
    except:
        ex = sys.exc_info()[0]
        msg = f'Read exception detected {ex}'
        pytest.fail(msg)


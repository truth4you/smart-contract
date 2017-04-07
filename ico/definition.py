"""Process YAML crowdsale definition files."""
import datetime
import time
from collections import OrderedDict

import ruamel.yaml
import jinja2

from eth_utils.currency import to_wei
from ruamel.yaml.comments import CommentedMap


def _datetime(*args) -> datetime.datetime:
    """Construct UTC datetime."""
    return datetime.datetime(*args, tzinfo=datetime.timezone.utc)


def _timestamp(dt) -> int:
    """Convert UTC datetime to unix timestamp."""
    epoch = datetime.datetime(1970, 1, 1, tzinfo=datetime.timezone.utc)
    t = (dt - epoch).total_seconds()
    return int(t)


def _time() -> int:
    """Current UNIX timestamp."""
    return int(time.time())


def extract_deployment_details(yaml_filename: str, chain: str) -> dict:
    """Read yaml definition file and interpolate all variables."""
    with open(yaml_filename, "rt") as inp:
        data = ruamel.yaml.load(inp, ruamel.yaml.RoundTripLoader)
        return data[chain]


def get_jinja_context(data: dict) -> dict:
    """Create Jinja template variables and functions"""

    # Define helper functions
    context = {
        "time": _time,
        "timestamp": _timestamp,
        "datetime": _datetime,
        "to_wei": to_wei,
    }

    # Copy run-time data to template context
    for key, value in data.items():
        context[key] = value

    return context


def interpolate_value(value: str, context: dict):
    """Expand Jinja templating in the definitions."""

    if type(value) == str and "{{" in value:
        t = jinja2.Template(value, undefined=jinja2.StrictUndefined)
        try:
            v = t.render(**context)
        except jinja2.exceptions.TemplateError as e:
            raise RuntimeError("Could not expand template value: {}".format(value)) from e

        # Jinja template rendering does not have explicit int support,
        # so we have this hack in place
        try:
            v = int(v)
        except ValueError:
            pass

        return v
    else:
        return value


def interpolate_data(data: dict, context: dict) -> dict:
    new = OrderedDict()
    for k, v in data.items():
        if isinstance(v, (dict, CommentedMap)):
            v = interpolate_data(v, context)
        elif isinstance(v, list):
            v = [interpolate_value(item , context) for item in v]
        else:
            v = interpolate_value(v, context)

        new[k] = v
    return new


def load_crowdsale_definitions(yaml_filename, chain: str):
    """Load crowdsale definitions from YAML file and replace all values."""
    data = extract_deployment_details(yaml_filename, chain)
    return data


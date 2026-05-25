from __future__ import annotations

from importlib.metadata import entry_points, version
from inspect import signature

from typer.testing import CliRunner

from agentfinder import cli

app = cli.app


def test_version_option_prints_installed_project_version() -> None:
    result = CliRunner().invoke(app, ["--version"])

    assert result.exit_code == 0
    assert result.output == f"agentfinder {version('hf-agentfinder')}\n"


def test_version_command_prints_installed_project_version() -> None:
    result = CliRunner().invoke(app, ["version"])

    assert result.exit_code == 0
    assert result.output == f"agentfinder {version('hf-agentfinder')}\n"


def test_package_exposes_hf_extension_console_script() -> None:
    scripts = entry_points(group="console_scripts")

    assert scripts["agentfinder"].value == "agentfinder.cli:app"
    assert scripts["hf-agentfinder"].value == "agentfinder.cli:app"


def test_search_commands_default_to_hosted_registry_urls() -> None:
    search_parameters = signature(cli.search_alias).parameters
    spaces_parameters = signature(cli.spaces_search).parameters

    assert search_parameters["registry_url"].default == cli.DEFAULT_REGISTRY_URL
    assert spaces_parameters["registry_url"].default == cli.DEFAULT_SPACES_REGISTRY_URL
    assert search_parameters["local"].default is False
    assert spaces_parameters["local"].default is False

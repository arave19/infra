import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def test_backend_uses_gcs_state_bucket():
    backend = read("backend.tf")

    assert 'backend "gcs"' in backend
    assert "habi-form-tfstate-aravel-344022-dev" in backend
    assert "infra/dev" in backend


def test_region_and_project_defaults_are_valid():
    variables = read("variables.tf")

    assert 'default = "aravel-344022"' in variables
    assert 'default = "us-central1"' in variables
    assert "us-cental1" not in variables
    assert 'default = "dev"' in variables


def test_main_stack_contains_required_gcp_resources():
    main = read("main.tf")

    required_resources = [
        "google_artifact_registry_repository",
        "google_storage_bucket",
        "google_bigquery_dataset",
        "google_bigquery_table",
        "google_pubsub_topic",
        "google_pubsub_subscription",
        "google_cloud_run_v2_service",
        "google_service_account",
        "null_resource",
    ]

    for resource in required_resources:
        assert resource in main

    assert "form_submissions" in main
    assert "call_attempts" in main
    assert "bulk_uploads" in main
    assert "dataflow.googleapis.com" in main
    assert "DATAFLOW_ENABLED" in main
    assert "process_call" in main
    assert "run_cloud_build" in main


def test_bigquery_schemas_have_required_fields():
    submissions = json.loads(read("schemas/form_submissions.json"))
    calls = json.loads(read("schemas/call_attempts.json"))
    bulk_uploads = json.loads(read("schemas/bulk_uploads.json"))

    submission_fields = {field["name"]: field for field in submissions}
    call_fields = {field["name"]: field for field in calls}
    bulk_fields = {field["name"]: field for field in bulk_uploads}

    assert submission_fields["submission_id"]["mode"] == "REQUIRED"
    assert submission_fields["telefonos"]["mode"] == "REPEATED"
    assert submission_fields["photo_url"]["type"] == "STRING"
    assert call_fields["submission_id"]["mode"] == "REQUIRED"
    assert call_fields["status"]["mode"] == "REQUIRED"
    assert call_fields["scheduled_visit"]["type"] == "BOOLEAN"
    assert bulk_fields["bulk_upload_id"]["mode"] == "REQUIRED"
    assert bulk_fields["processing_mode"]["mode"] == "REQUIRED"
    assert bulk_fields["valid_count"]["type"] == "INTEGER"


def test_bootstrap_creates_state_bucket():
    bootstrap = read("bootstrap/main.tf")

    assert "google_storage_bucket" in bootstrap
    assert "terraform_state" in bootstrap
    assert "versioning" in bootstrap


def test_data_contract_and_consumption_sql_exist():
    contract = json.loads(read("contracts/form_submissions_contract_v1.json"))
    sql = read("sql/consumption_contactability.sql")

    field_names = {field["name"] for field in contract["fields"]}

    assert contract["version"] == "1.0.0"
    assert "submission_id" in contract["primary_key"]
    assert {"submission_id", "created_at", "telefonos", "photo_url"}.issubset(field_names)
    assert "v_contactability_summary" in sql
    assert "v_contactability_kpis" in sql

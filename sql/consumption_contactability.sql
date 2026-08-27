-- Consumption layer example for Habi lead contactability.
-- Replace `aravel-344022.habi_form_dev` if deploying in another project/env.

CREATE OR REPLACE VIEW `aravel-344022.habi_form_dev.v_contactability_summary` AS
WITH submissions AS (
  SELECT
    submission_id,
    created_at,
    source,
    nombre,
    descripcion,
    latitude,
    longitude,
    photo_url,
    ARRAY_LENGTH(telefonos) AS phone_count
  FROM `aravel-344022.habi_form_dev.form_submissions`
),
latest_call AS (
  SELECT
    submission_id,
    status,
    selected_phone,
    response,
    scheduled_visit,
    next_action,
    created_at AS call_created_at
  FROM `aravel-344022.habi_form_dev.call_attempts`
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY submission_id
    ORDER BY created_at DESC
  ) = 1
)
SELECT
  s.submission_id,
  s.created_at,
  s.source,
  s.nombre,
  s.descripcion,
  s.latitude,
  s.longitude,
  s.photo_url,
  s.phone_count,
  c.status AS latest_call_status,
  c.selected_phone,
  c.response,
  c.scheduled_visit,
  c.next_action,
  c.call_created_at,
  TIMESTAMP_DIFF(c.call_created_at, s.created_at, MINUTE) AS minutes_to_call
FROM submissions s
LEFT JOIN latest_call c
  USING (submission_id);

CREATE OR REPLACE VIEW `aravel-344022.habi_form_dev.v_contactability_kpis` AS
SELECT
  DATE(created_at) AS submission_date,
  source,
  COUNT(*) AS submissions,
  COUNTIF(phone_count > 0) AS submissions_with_phone,
  COUNTIF(latest_call_status = 'successful') AS successful_calls,
  COUNTIF(scheduled_visit) AS scheduled_visits,
  SAFE_DIVIDE(COUNTIF(latest_call_status = 'successful'), COUNT(*)) AS call_success_rate,
  SAFE_DIVIDE(COUNTIF(scheduled_visit), COUNT(*)) AS visit_schedule_rate,
  AVG(minutes_to_call) AS avg_minutes_to_call
FROM `aravel-344022.habi_form_dev.v_contactability_summary`
GROUP BY submission_date, source;

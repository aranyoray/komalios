# Guardian Dashboard Demo

Streamlit-based dashboard for parents/guardians to review their child's avatar creations and session activity.

## Requirements

- Python 3.8+
- streamlit
- pandas
- plotly

## Setup

```bash
pip install streamlit pandas plotly
streamlit run app.py
```

## Features

- View child's saved avatars
- Session activity timeline
- Emotion usage analytics
- Export reports (PDF/CSV)
- Privacy-first design

## Files

- `app.py` - Main Streamlit dashboard
- `report_generator.py` - PDF/CSV report generation

## Usage

```bash
streamlit run app.py --server.port 8501
```

Then open http://localhost:8501 in your browser.

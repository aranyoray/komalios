#!/usr/bin/env python3
"""
Guardian Dashboard - Streamlit app for parents to review child activity
Required packages: streamlit, pandas, plotly
"""

import streamlit as st
import pandas as pd
import json
from datetime import datetime, timedelta
import random
from pathlib import Path

# Page config
st.set_page_config(
    page_title="Komal Guardian Dashboard",
    page_icon="👨‍👩‍👧",
    layout="wide"
)

# Sample data generation
def generate_sample_sessions(n=20):
    """Generate sample session data for demo."""
    emojis = ['smile', 'big_smile', 'soft_smile', 'laughing', 'blushing',
              'excited', 'curious', 'grateful', 'friendly_wink', 'caring_smile']

    sessions = []
    base_date = datetime.now() - timedelta(days=30)

    for i in range(n):
        session_date = base_date + timedelta(days=random.randint(0, 30))
        sessions.append({
            'session_id': f'sess_{i:03d}',
            'date': session_date.strftime('%Y-%m-%d'),
            'time': f'{random.randint(9, 18):02d}:{random.randint(0, 59):02d}',
            'duration_min': random.randint(5, 30),
            'avatars_created': random.randint(1, 5),
            'primary_emotion': random.choice(emojis),
            'exports': random.randint(0, 3)
        })

    return pd.DataFrame(sessions)

def generate_emotion_stats(sessions_df):
    """Generate emotion usage statistics."""
    emotion_counts = sessions_df['primary_emotion'].value_counts()
    return emotion_counts

# Main app
def main():
    st.title("👨‍👩‍👧 Guardian Dashboard")
    st.markdown("Review your child's Komal avatar activity")

    # Sidebar
    st.sidebar.header("Settings")
    child_name = st.sidebar.text_input("Child's Name", "Alex")
    date_range = st.sidebar.selectbox(
        "Time Period",
        ["Last 7 days", "Last 30 days", "All time"]
    )

    # Generate sample data
    sessions_df = generate_sample_sessions()

    # Overview metrics
    st.header(f"Activity Overview for {child_name}")

    col1, col2, col3, col4 = st.columns(4)
    with col1:
        st.metric("Total Sessions", len(sessions_df))
    with col2:
        st.metric("Avatars Created", sessions_df['avatars_created'].sum())
    with col3:
        st.metric("Avg Session", f"{sessions_df['duration_min'].mean():.0f} min")
    with col4:
        st.metric("Exports", sessions_df['exports'].sum())

    # Emotion analytics
    st.header("Emotion Usage")

    emotion_stats = generate_emotion_stats(sessions_df)

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Most Used Expressions")
        st.bar_chart(emotion_stats)

    with col2:
        st.subheader("Emotion Distribution")
        # Display as dataframe
        emotion_df = pd.DataFrame({
            'Emotion': emotion_stats.index,
            'Count': emotion_stats.values,
            'Percentage': (emotion_stats.values / emotion_stats.sum() * 100).round(1)
        })
        st.dataframe(emotion_df, hide_index=True)

    # Recent sessions
    st.header("Recent Sessions")

    # Sort by date and display
    recent = sessions_df.sort_values('date', ascending=False).head(10)
    st.dataframe(
        recent[['date', 'time', 'duration_min', 'avatars_created', 'primary_emotion', 'exports']],
        hide_index=True,
        column_config={
            'date': 'Date',
            'time': 'Time',
            'duration_min': 'Duration (min)',
            'avatars_created': 'Avatars',
            'primary_emotion': 'Main Emotion',
            'exports': 'Saved'
        }
    )

    # Export options
    st.header("Export Reports")

    col1, col2 = st.columns(2)

    with col1:
        if st.button("Download CSV Report"):
            csv = sessions_df.to_csv(index=False)
            st.download_button(
                label="Click to Download",
                data=csv,
                file_name=f"komal_report_{child_name}_{datetime.now().strftime('%Y%m%d')}.csv",
                mime="text/csv"
            )

    with col2:
        if st.button("Generate Summary"):
            summary = f"""
            ## Activity Summary for {child_name}

            **Period:** {date_range}
            **Total Sessions:** {len(sessions_df)}
            **Total Avatars Created:** {sessions_df['avatars_created'].sum()}
            **Average Session Duration:** {sessions_df['duration_min'].mean():.1f} minutes
            **Most Used Expression:** {emotion_stats.index[0]}

            *Generated on {datetime.now().strftime('%Y-%m-%d %H:%M')}*
            """
            st.markdown(summary)

    # Privacy notice
    st.divider()
    st.caption("🔒 All data is stored locally on your device. No data is sent to external servers.")

if __name__ == '__main__':
    main()

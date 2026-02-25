"""
IRB Model Validation Dashboard
================================
Run:
    pip install -r requirements.txt
    python app.py

Then open: http://localhost:8050
"""

import os
import dash
from dash import html, dcc, dash_table
import plotly.graph_objects as go
import pandas as pd

# ============================================================================
# VALIDATION RESULTS (from SAS output)
# ============================================================================

auc_data = pd.DataFrame({
    'Segment': ['OVERALL', 'CORPORATE', 'SME', 'RETAIL'],
    'AUC': [0.6219, 0.6922, 0.5747, 0.6043],
    'Gini': [0.2437, 0.3843, 0.1494, 0.2086],
    'RAG': ['AMBER', 'AMBER', 'RED', 'AMBER']
})

calib_data = pd.DataFrame({
    'Decile': list(range(10)),
    'Predicted_PD': [0.680, 0.903, 1.075, 1.241, 1.425, 1.623, 1.858, 2.150, 2.601, 3.755],
    'Observed_DR': [0.900, 1.200, 1.400, 1.200, 1.900, 1.600, 2.200, 3.100, 2.500, 3.700]
})
calib_data['Bias'] = calib_data['Observed_DR'] - calib_data['Predicted_PD']

lgd_data = pd.DataFrame({
    'Segment': ['CORPORATE', 'RETAIL', 'SME'],
    'Predicted_LGD': [48.42, 48.96, 47.42],
    'Realized_LGD': [51.92, 47.68, 48.80],
    'Bias': [3.50, -1.28, 1.37]
})

stress_data = pd.DataFrame({
    'Scenario': ['Base Case', '10% Haircut', '20% Haircut', '30% Severe'],
    'Stressed_LGD': [49.50, 54.45, 59.60, 64.65],
    'Model_LGD': [48.20, 48.20, 48.20, 48.20]
})

findings_data = pd.DataFrame({
    'ID': ['F001', 'F002', 'F003', 'F004'],
    'Module': ['PD', 'PD', 'PD', 'LGD'],
    'Test': ['Overall AUC', 'Calibration', 'PSI Stability', 'LGD Accuracy'],
    'RAG': ['AMBER', 'GREEN', 'GREEN', 'GREEN'],
    'Finding': [
        'AUC=0.6219 below 0.70 target',
        'Calibration bias 0.24% acceptable',
        'Score distribution stable',
        'LGD bias within tolerance'
    ]
})

# ============================================================================
# CHARTS
# ============================================================================

rag_colors = {'GREEN': '#27ae60', 'AMBER': '#f39c12', 'RED': '#e74c3c'}

# 1. AUC bar chart
fig_auc = go.Figure(go.Bar(
    x=auc_data['Segment'], y=auc_data['AUC'],
    marker_color=[rag_colors[r] for r in auc_data['RAG']],
    text=auc_data['AUC'].round(4), textposition='outside'
))
fig_auc.add_hline(y=0.70, line_dash="dash", line_color="green",
                  annotation_text="Target (0.70)")
fig_auc.add_hline(y=0.60, line_dash="dash", line_color="orange",
                  annotation_text="Minimum (0.60)")
fig_auc.update_layout(title="PD Model Discrimination (AUC)",
                      yaxis_title="AUC", yaxis_range=[0, 1],
                      template="plotly_white", height=450)

# 2. Calibration curve
fig_calib = go.Figure()
fig_calib.add_trace(go.Scatter(
    x=calib_data['Predicted_PD'], y=calib_data['Observed_DR'],
    mode='markers+lines', name='Observed',
    marker=dict(size=10, color='#1f77b4')
))
fig_calib.add_trace(go.Scatter(
    x=[0, 4], y=[0, 4], mode='lines', name='Perfect',
    line=dict(dash='dash', color='gray')
))
fig_calib.update_layout(title="Calibration Curve",
                        xaxis_title="Predicted PD (%)",
                        yaxis_title="Observed DR (%)",
                        template="plotly_white", height=450)

# 3. LGD comparison
fig_lgd = go.Figure(data=[
    go.Bar(name='Predicted', x=lgd_data['Segment'], y=lgd_data['Predicted_LGD'],
           marker_color='#3498db'),
    go.Bar(name='Realized', x=lgd_data['Segment'], y=lgd_data['Realized_LGD'],
           marker_color='#e67e22')
])
fig_lgd.update_layout(title="LGD: Predicted vs Realized (%)",
                      barmode='group', template="plotly_white", height=450)

# 4. Stress test
fig_stress = go.Figure(data=[
    go.Bar(name='Stressed LGD', x=stress_data['Scenario'],
           y=stress_data['Stressed_LGD'],
           marker_color=['#2ecc71', '#f39c12', '#e74c3c', '#c0392b']),
    go.Scatter(name='Model LGD', x=stress_data['Scenario'],
               y=stress_data['Model_LGD'],
               mode='lines+markers', line=dict(color='black', dash='dash'))
])
fig_stress.update_layout(title="LGD Downturn Stress Test",
                         yaxis_title="LGD (%)",
                         template="plotly_white", height=450)

# ============================================================================
# DASH APP
# ============================================================================

app = dash.Dash(__name__)
server = app.server  # for deployment

def kpi_card(title, value, subtitle, color='#2c3e50'):
    return html.Div([
        html.P(title, style={'color': '#7f8c8d', 'fontSize': '14px', 'margin': '0'}),
        html.H2(value, style={'color': color, 'margin': '5px 0', 'fontSize': '36px'}),
        html.Span(subtitle, style={
            'backgroundColor': color, 'color': 'white',
            'padding': '3px 10px', 'borderRadius': '4px', 'fontSize': '12px'
        })
    ], style={
        'textAlign': 'center', 'padding': '20px', 'backgroundColor': 'white',
        'borderRadius': '8px', 'boxShadow': '0 2px 4px rgba(0,0,0,0.1)',
        'width': '22%', 'display': 'inline-block', 'margin': '0.5%'
    })

app.layout = html.Div([
    # Header
    html.Div([
        html.H1("IRB Credit Model Validation", style={'color': 'white', 'margin': '0'}),
        html.P("PD / LGD / EAD-CCF | CRR & EBA GL/2017/16",
               style={'color': '#bdc3c7'}),
    ], style={'backgroundColor': '#2c3e50', 'padding': '25px'}),

    # KPI row
    html.Div([
        kpi_card("Overall AUC", "0.6219", "AMBER", '#f39c12'),
        kpi_card("Calibration Bias", "0.24%", "GREEN", '#27ae60'),
        kpi_card("Default Rate", "1.97%", "197 / 10,000", '#2c3e50'),
        kpi_card("Findings", "4", "1 Amber | 3 Green", '#2c3e50'),
    ], style={'textAlign': 'center', 'padding': '20px'}),

    # Charts
    html.Div([
        html.Div([dcc.Graph(figure=fig_auc)],
                 style={'width': '48%', 'display': 'inline-block', 'padding': '1%'}),
        html.Div([dcc.Graph(figure=fig_calib)],
                 style={'width': '48%', 'display': 'inline-block', 'padding': '1%'}),
    ]),
    html.Div([
        html.Div([dcc.Graph(figure=fig_lgd)],
                 style={'width': '48%', 'display': 'inline-block', 'padding': '1%'}),
        html.Div([dcc.Graph(figure=fig_stress)],
                 style={'width': '48%', 'display': 'inline-block', 'padding': '1%'}),
    ]),

    # Findings table
    html.Div([
        html.H3("Validation Findings Log"),
        dash_table.DataTable(
            data=findings_data.to_dict('records'),
            columns=[{'name': c, 'id': c} for c in findings_data.columns],
            style_cell={'textAlign': 'left', 'padding': '10px'},
            style_header={'backgroundColor': '#2c3e50', 'color': 'white',
                          'fontWeight': 'bold'},
            style_data_conditional=[
                {'if': {'filter_query': '{RAG} = "RED"'},
                 'backgroundColor': '#fadbd8'},
                {'if': {'filter_query': '{RAG} = "AMBER"'},
                 'backgroundColor': '#fdebd0'},
                {'if': {'filter_query': '{RAG} = "GREEN"'},
                 'backgroundColor': '#d5f5e3'},
            ]
        )
    ], style={'padding': '20px'}),

    # Footer
    html.P("Built with SAS + Python/Dash | IRB Validation Toolkit",
           style={'textAlign': 'center', 'color': '#95a5a6', 'padding': '20px'})

], style={'backgroundColor': '#ecf0f1', 'fontFamily': 'Segoe UI, sans-serif'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8050))
    app.run(debug=True, host='0.0.0.0', port=port)

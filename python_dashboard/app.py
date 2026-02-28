"""
IRB Model Validation Dashboard
"""

import os
import dash
from dash import html, dcc, dash_table
import plotly.graph_objects as go
import pandas as pd

# ============================================================================
# YOUR ACTUAL SAS RESULTS
# ============================================================================

auc_data = pd.DataFrame({
    "Segment": ["OVERALL", "CORPORATE", "SME", "RETAIL"],
    "AUC": [0.6176, 0.6140, 0.5920, 0.6234],
    "Gini": [0.2352, 0.2280, 0.1841, 0.2467],
    "RAG": ["AMBER", "AMBER", "RED", "AMBER"]
})

calib_data = pd.DataFrame({
    "Decile": list(range(10)),
    "Predicted_PD": [0.682, 0.900, 1.074, 1.242, 1.419, 1.612, 1.842, 2.146, 2.588, 3.707],
    "Observed_DR": [1.600, 0.900, 1.100, 1.400, 1.500, 2.600, 2.100, 3.200, 2.700, 4.000]
})

lgd_data = pd.DataFrame({
    "Segment": ["CORPORATE", "RETAIL", "SME"],
    "Predicted_LGD": [48.18, 48.40, 49.59],
    "Realized_LGD": [50.93, 52.06, 53.48],
    "Bias": [2.75, 3.66, 3.89]
})

stress_data = pd.DataFrame({
    "Scenario": ["Base Case", "10% Haircut", "20% Haircut", "30% Severe"],
    "Stressed_LGD": [52.19, 56.97, 61.75, 66.53],
    "Model_LGD": [48.77, 48.77, 48.77, 48.77]
})

ccf_data = pd.DataFrame({
    "Segment": ["CORPORATE", "RETAIL", "SME"],
    "Predicted_CCF": [35.98, 37.16, 36.84],
    "Realized_CCF": [36.65, 39.89, 41.34],
    "Bias": [0.67, 2.73, 4.50]
})

findings_list = [
    {"ID": "F001", "Module": "DATA_QUALITY", "Test": "Missing - LGD",
     "Severity": 2, "RAG": "RED",
     "Finding": "predicted_lgd 97.9% missing (expected for non-defaults)"},
    {"ID": "F002", "Module": "DATA_QUALITY", "Test": "Missing - Recovery",
     "Severity": 2, "RAG": "RED",
     "Finding": "recovery_months 97.9% missing (expected for non-defaults)"},
    {"ID": "F003", "Module": "DATA_QUALITY", "Test": "Missing - Realized LGD",
     "Severity": 2, "RAG": "RED",
     "Finding": "realized_lgd 97.9% missing (expected for non-defaults)"},
    {"ID": "F004", "Module": "PD", "Test": "Overall AUC",
     "Severity": 3, "RAG": "AMBER",
     "Finding": "AUC=0.6176 below 0.70 target"},
    {"ID": "F005", "Module": "PD", "Test": "SME Segment AUC",
     "Severity": 2, "RAG": "RED",
     "Finding": "SME segment AUC=0.5920 below minimum threshold"}
]

override_data = pd.DataFrame({
    "Status": ["Not Overridden", "Overridden"],
    "Accounts": [8990, 1010],
    "Defaults": [186, 25],
    "Default_Rate": [2.07, 2.48],
    "Avg_PD": [1.72, 1.71]
})

# ============================================================================
# CHARTS
# ============================================================================

rag_colors = {"GREEN": "#27ae60", "AMBER": "#f39c12", "RED": "#e74c3c"}

# 1. AUC by Segment
fig_auc = go.Figure(go.Bar(
    x=auc_data["Segment"], y=auc_data["AUC"],
    marker_color=[rag_colors[r] for r in auc_data["RAG"]],
    text=auc_data["AUC"].round(4), textposition="outside"
))
fig_auc.add_hline(y=0.70, line_dash="dash", line_color="green",
                  annotation_text="Target (0.70)")
fig_auc.add_hline(y=0.60, line_dash="dash", line_color="orange",
                  annotation_text="Minimum (0.60)")
fig_auc.update_layout(
    title="PD Model Discrimination (AUC) by Segment",
    yaxis_title="AUC", yaxis_range=[0, 1],
    template="plotly_white", height=450
)

# 2. Calibration Curve
fig_calib = go.Figure()
fig_calib.add_trace(go.Scatter(
    x=calib_data["Predicted_PD"], y=calib_data["Observed_DR"],
    mode="markers+lines", name="Observed DR",
    marker=dict(size=10, color="#1f77b4")
))
fig_calib.add_trace(go.Scatter(
    x=[0, 5], y=[0, 5], mode="lines", name="Perfect Calibration",
    line=dict(dash="dash", color="gray")
))
fig_calib.update_layout(
    title="PD Calibration Curve",
    xaxis_title="Predicted PD (%)",
    yaxis_title="Observed Default Rate (%)",
    template="plotly_white", height=450
)

# 3. LGD Comparison
fig_lgd = go.Figure(data=[
    go.Bar(name="Predicted LGD", x=lgd_data["Segment"],
           y=lgd_data["Predicted_LGD"], marker_color="#3498db"),
    go.Bar(name="Realized LGD", x=lgd_data["Segment"],
           y=lgd_data["Realized_LGD"], marker_color="#e67e22")
])
fig_lgd.update_layout(
    title="LGD: Predicted vs Realized by Segment (%)",
    barmode="group", template="plotly_white", height=450,
    yaxis_title="LGD (%)"
)

# 4. Stress Test
fig_stress = go.Figure(data=[
    go.Bar(name="Stressed LGD", x=stress_data["Scenario"],
           y=stress_data["Stressed_LGD"],
           marker_color=["#2ecc71", "#f39c12", "#e74c3c", "#c0392b"]),
    go.Scatter(name="Model LGD", x=stress_data["Scenario"],
               y=stress_data["Model_LGD"],
               mode="lines+markers",
               line=dict(color="black", dash="dash"))
])
fig_stress.update_layout(
    title="LGD Downturn Stress Test (%)",
    yaxis_title="LGD (%)",
    template="plotly_white", height=450
)

# 5. CCF Comparison
fig_ccf = go.Figure(data=[
    go.Bar(name="Predicted CCF", x=ccf_data["Segment"],
           y=ccf_data["Predicted_CCF"], marker_color="#3498db"),
    go.Bar(name="Realized CCF", x=ccf_data["Segment"],
           y=ccf_data["Realized_CCF"], marker_color="#e67e22")
])
fig_ccf.update_layout(
    title="CCF: Predicted vs Realized by Segment (%)",
    barmode="group", template="plotly_white", height=450,
    yaxis_title="CCF (%)"
)

# 6. Override Impact
fig_override = go.Figure(data=[
    go.Bar(name="Default Rate %", x=override_data["Status"],
           y=override_data["Default_Rate"],
           marker_color=["#3498db", "#e74c3c"],
           text=override_data["Default_Rate"], textposition="outside")
])
fig_override.update_layout(
    title="Override Impact on Default Rates",
    yaxis_title="Default Rate (%)",
    template="plotly_white", height=400
)

# ============================================================================
# DASH APP
# ============================================================================

app = dash.Dash(__name__)
server = app.server


def kpi_card(title, value, status, color):
    return html.Div([
        html.P(title, style={
            "color": "#7f8c8d", "fontSize": "13px",
            "margin": "0", "fontWeight": "bold"
        }),
        html.H2(value, style={
            "color": color, "margin": "5px 0", "fontSize": "32px"
        }),
        html.Span(status, style={
            "backgroundColor": color, "color": "white",
            "padding": "3px 10px", "borderRadius": "4px", "fontSize": "11px"
        })
    ], style={
        "textAlign": "center", "padding": "15px",
        "backgroundColor": "white", "borderRadius": "8px",
        "boxShadow": "0 2px 4px rgba(0,0,0,0.1)",
        "width": "15%", "display": "inline-block",
        "margin": "0.5%", "verticalAlign": "top"
    })


# Findings table columns
findings_columns = [
    {"name": "ID", "id": "ID"},
    {"name": "Module", "id": "Module"},
    {"name": "Test", "id": "Test"},
    {"name": "Severity", "id": "Severity"},
    {"name": "RAG", "id": "RAG"},
    {"name": "Finding", "id": "Finding"}
]

# Conditional styling for findings table
findings_style = [
    {
        "if": {"filter_query": "{RAG} = RED"},
        "backgroundColor": "#fadbd8"
    },
    {
        "if": {"filter_query": "{RAG} = AMBER"},
        "backgroundColor": "#fdebd0"
    },
    {
        "if": {"filter_query": "{RAG} = GREEN"},
        "backgroundColor": "#d5f5e3"
    }
]

app.layout = html.Div([
    # Header
    html.Div([
        html.H1("IRB Credit Model Validation Dashboard",
                style={"color": "white", "margin": "0"}),
        html.P("PD / LGD / EAD-CCF | CRR & EBA GL/2017/16",
               style={"color": "#bdc3c7", "margin": "5px 0"}),
        html.P(
            "10,000 Accounts | 211 Defaults | 2.11% Default Rate | Feb 2026",
            style={"color": "#95a5a6", "fontSize": "13px", "margin": "0"}
        )
    ], style={"backgroundColor": "#2c3e50", "padding": "25px"}),

    # KPI Cards
    html.Div([
        kpi_card("Overall AUC", "0.6176", "AMBER", "#f39c12"),
        kpi_card("Gini", "0.2352", "AMBER", "#f39c12"),
        kpi_card("Calibration Bias", "0.39%", "GREEN", "#27ae60"),
        kpi_card("LGD Bias", "3.42%", "GREEN", "#27ae60"),
        kpi_card("EAD Ratio", "1.013", "GREEN", "#27ae60"),
        kpi_card("Findings", "5 Total", "3 RED | 1 AMBER", "#e74c3c"),
    ], style={"textAlign": "center", "padding": "15px 0"}),

    # PD Section
    html.H2("PD Model Validation", style={
        "padding": "10px 20px", "color": "#2c3e50",
        "borderBottom": "2px solid #3498db"
    }),
    html.Div([
        html.Div([dcc.Graph(figure=fig_auc)],
                 style={"width": "48%", "display": "inline-block",
                        "padding": "1%"}),
        html.Div([dcc.Graph(figure=fig_calib)],
                 style={"width": "48%", "display": "inline-block",
                        "padding": "1%"}),
    ]),

    # LGD Section
    html.H2("LGD Model Validation", style={
        "padding": "10px 20px", "color": "#2c3e50",
        "borderBottom": "2px solid #e67e22"
    }),
    html.Div([
        html.Div([dcc.Graph(figure=fig_lgd)],
                 style={"width": "48%", "display": "inline-block",
                        "padding": "1%"}),
        html.Div([dcc.Graph(figure=fig_stress)],
                 style={"width": "48%", "display": "inline-block",
                        "padding": "1%"}),
    ]),

    # CCF + Override Section
    html.H2("EAD/CCF & Override Analysis", style={
        "padding": "10px 20px", "color": "#2c3e50",
        "borderBottom": "2px solid #27ae60"
    }),
    html.Div([
        html.Div([dcc.Graph(figure=fig_ccf)],
                 style={"width": "48%", "display": "inline-block",
                        "padding": "1%"}),
        html.Div([dcc.Graph(figure=fig_override)],
                 style={"width": "48%", "display": "inline-block",
                        "padding": "1%"}),
    ]),

    # Findings Table
    html.H2("Validation Findings Log", style={
        "padding": "10px 20px", "color": "#2c3e50",
        "borderBottom": "2px solid #e74c3c"
    }),
    html.Div([
        dash_table.DataTable(
            data=findings_list,
            columns=findings_columns,
            style_cell={
                "textAlign": "left",
                "padding": "10px",
                "fontSize": "13px"
            },
            style_header={
                "backgroundColor": "#2c3e50",
                "color": "white",
                "fontWeight": "bold"
            },
            style_data_conditional=findings_style
        )
    ], style={"padding": "10px 20px"}),

    # Footer
    html.Div([
        html.Hr(),
        html.P(
            "IRB Credit Model Validation Toolkit | Built with SAS & Python/Dash",
            style={
                "textAlign": "center",
                "color": "#95a5a6",
                "padding": "10px"
            }
        )
    ])

], style={"backgroundColor": "#ecf0f1", "fontFamily": "Segoe UI, sans-serif"})

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8050))
    app.run(debug=False, host="0.0.0.0", port=port)

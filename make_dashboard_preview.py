"""
make_dashboard_preview.py
Renders a static layout preview of the Power BI dashboard (docs/dashboard_preview.png)
from data/processed/sales_flat.csv. The real, interactive dashboard is built in Power BI Desktop
(see powerbi/dashboard_build_guide.md) - replace this image with a screenshot of it.
"""
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
df = pd.read_csv(ROOT / "data" / "processed" / "sales_flat.csv")

NAVY, BLUE, TEAL, AMBER, RED, VIOLET, SKY, GREY = "#0B1F3A", "#1F6FEB", "#12B5A5", "#F5A623", "#E5484D", "#7C5CFC", "#3DB2FF", "#8B9BB4"
BG, CARD, TEXT = "#F4F6FA", "#FFFFFF", "#1B2A41"
plt.rcParams.update({"font.family": "DejaVu Sans", "axes.edgecolor": "#DDE3EE", "text.color": TEXT})

fig = plt.figure(figsize=(16, 9), facecolor=BG)

# ---- header ----
hdr = fig.add_axes([0, 0.92, 1, 0.08]); hdr.set_facecolor(NAVY); hdr.set_xticks([]); hdr.set_yticks([])
for s in hdr.spines.values(): s.set_visible(False)
hdr.text(0.02, 0.5, "Sales Performance Dashboard", color="white", fontsize=20, fontweight="bold", va="center", transform=hdr.transAxes)
hdr.text(0.98, 0.5, "Jan - Dec 2026  |  5 regions  |  4 channels  |  15 salespeople", color="#B8C4DA", fontsize=11, va="center", ha="right", transform=hdr.transAxes)

# ---- KPI cards ----
rev, orders, units = df.net_revenue.sum(), df.order_id.nunique(), df.quantity.sum()
disc_rate = df.discount_amount.sum() / df.gross_revenue.sum()
kpis = [("Total Revenue", f"${rev/1e6:.2f}M", BLUE), ("Total Orders", f"{orders:,}", TEAL),
        ("Avg Order Value", f"${rev/orders:,.0f}", VIOLET), ("Units Sold", f"{units:,}", AMBER),
        ("Discount Rate", f"{disc_rate:.1%}", RED)]
for i, (label, value, color) in enumerate(kpis):
    ax = fig.add_axes([0.015 + i * 0.1975, 0.775, 0.19, 0.125]); ax.axis("off")
    ax.add_patch(FancyBboxPatch((0, 0), 1, 1, boxstyle="round,pad=0,rounding_size=0.06", fc=CARD, ec="#E3E8F1", transform=ax.transAxes))
    ax.add_patch(plt.Rectangle((0, 0.08), 0.018, 0.84, color=color, transform=ax.transAxes))
    ax.text(0.08, 0.68, label, fontsize=11, color=GREY, transform=ax.transAxes)
    ax.text(0.08, 0.20, value, fontsize=26, fontweight="bold", color=NAVY, transform=ax.transAxes)

def card(rect, title, lm=0.015):
    """White card with a title; returns an inner axes inset by `lm` (room for y-labels)."""
    x, y, w, h = rect
    bg = fig.add_axes(rect); bg.set_xticks([]); bg.set_yticks([]); bg.set_facecolor(CARD)
    for sp in bg.spines.values(): sp.set_color("#E3E8F1")
    bg.text(0.02, 0.90, title, fontsize=12, fontweight="bold", color=NAVY, transform=bg.transAxes, va="bottom")
    ax = fig.add_axes([x + lm, y + 0.035, w - lm - 0.015, h - 0.10])
    ax.set_facecolor(CARD)
    for sp in ax.spines.values(): sp.set_color("#E3E8F1")
    ax.tick_params(colors=GREY, labelsize=9, length=0)
    return ax

# ---- monthly revenue ----
m = df.groupby("year_month").net_revenue.sum() / 1000
ax = card([0.015, 0.40, 0.425, 0.34], "Monthly Revenue ($K)", lm=0.04)
ax.fill_between(range(len(m)), m.values, color=BLUE, alpha=0.15)
ax.plot(range(len(m)), m.values, color=BLUE, lw=2.5, marker="o", ms=5)
ax.set_xticks(range(len(m))); ax.set_xticklabels(["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"])
ax.set_ylim(0, m.max() * 1.2); ax.grid(axis="y", color="#EEF1F7")
pk = m.values.argmax(); ax.annotate(f"Peak: ${m.max():.0f}K", (pk, m.max()), xytext=(pk-1.5, m.max()*1.1), fontsize=9, color=RED, fontweight="bold")

# ---- category ----
c = df.groupby("product_category").net_revenue.sum().sort_values() / 1000
ax = card([0.45, 0.40, 0.25, 0.34], "Revenue by Category ($K)", lm=0.09)
ax.barh(c.index, c.values, color=[BLUE if v == c.max() else SKY for v in c.values], height=0.65)
for y, v in enumerate(c.values): ax.text(v + c.max()*0.02, y, f"{v:,.0f}", va="center", fontsize=9, color=NAVY)
ax.set_xlim(0, c.max() * 1.22); ax.set_xticks([]); ax.spines[["top", "right", "bottom"]].set_visible(False)

# ---- channel donut ----
ch = df.groupby("sales_channel").net_revenue.sum().sort_values(ascending=False)
ax = card([0.71, 0.40, 0.275, 0.34], "Revenue by Channel", lm=0.005)
ax.set_xticks([]); ax.set_yticks([]); [sp.set_visible(False) for sp in ax.spines.values()]
w, _ = ax.pie(ch.values, colors=[BLUE, TEAL, AMBER, VIOLET], startangle=90, counterclock=False, wedgeprops=dict(width=0.38, edgecolor="white"), center=(-0.25, 0), radius=0.95)
ax.set_xlim(-1.3, 1.9); ax.set_ylim(-1.1, 1.1)
ax.text(-0.25, 0, f"${ch.sum()/1e6:.1f}M", ha="center", va="center", fontsize=13, fontweight="bold", color=NAVY)
for i, (n, v) in enumerate(ch.items()):
    ax.text(0.95, 0.55 - i * 0.38, f"{n}\n{v/ch.sum():.0%}", fontsize=9, color=NAVY, va="center")
    ax.add_patch(plt.Rectangle((0.8, 0.5 - i * 0.38), 0.09, 0.12, color=[BLUE, TEAL, AMBER, VIOLET][i]))

# ---- region ----
r = df.groupby("region").net_revenue.sum().sort_values(ascending=False) / 1000
ax = card([0.015, 0.06, 0.29, 0.31], "Revenue by Region ($K)")
ax.bar(r.index, r.values, color=[TEAL if v == r.max() else "#7FD8CF" for v in r.values], width=0.6)
for x, v in enumerate(r.values): ax.text(x, v + r.max()*0.02, f"{v:,.0f}", ha="center", fontsize=9, color=NAVY)
ax.set_ylim(0, r.max() * 1.18); ax.set_yticks([]); ax.spines[["top", "right", "left"]].set_visible(False)

# ---- new vs returning by channel ----
p = df.pivot_table(index="sales_channel", columns="customer_type", values="net_revenue", aggfunc="sum")
p = p.div(p.sum(axis=1), axis=0).loc[ch.index[::-1]]
ax = card([0.315, 0.06, 0.34, 0.31], "New vs Returning Customers by Channel", lm=0.095)
ax.barh(p.index, p["Returning"], color=BLUE, height=0.55, label="Returning")
ax.barh(p.index, p["New"], left=p["Returning"], color=AMBER, height=0.55, label="New")
for y, v in enumerate(p["Returning"]): ax.text(v/2, y, f"{v:.0%}", ha="center", va="center", color="white", fontsize=9, fontweight="bold")
ax.set_xlim(0, 1); ax.set_xticks([]); ax.spines[["top", "right", "bottom"]].set_visible(False)
ax.legend(loc="lower right", bbox_to_anchor=(1.0, 1.02), ncol=2, frameon=False, fontsize=9)

# ---- top products ----
t = df.groupby("product").net_revenue.sum().sort_values().tail(5) / 1000
ax = card([0.665, 0.06, 0.32, 0.31], "Top 5 Products ($K)", lm=0.09)
ax.barh(t.index, t.values, color=VIOLET, height=0.6)
for y, v in enumerate(t.values): ax.text(v + t.max()*0.02, y, f"{v:,.0f}", va="center", fontsize=9, color=NAVY)
ax.set_xlim(0, t.max() * 1.2); ax.set_xticks([]); ax.spines[["top", "right", "bottom"]].set_visible(False)

fig.text(0.5, 0.012, "Layout preview generated with Python/matplotlib from the processed data. The interactive dashboard is built in Power BI Desktop - see powerbi/dashboard_build_guide.md",
         ha="center", fontsize=9, color=GREY)
fig.savefig(ROOT / "docs" / "dashboard_preview.png", dpi=110, facecolor=BG)
print("saved docs/dashboard_preview.png")

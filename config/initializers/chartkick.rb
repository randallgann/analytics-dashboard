Chartkick.options = {
  colors: ["#60a5fa", "#34d399", "#f97316", "#a78bfa", "#fb7185", "#fbbf24"],
  library: {
    plugins: {
      legend: { labels: { color: "#94a3b8", font: { size: 12 } } },
      tooltip: {
        backgroundColor: "#1e293b",
        titleColor: "#f1f5f9",
        bodyColor: "#94a3b8",
        borderColor: "#334155",
        borderWidth: 1
      }
    },
    scales: {
      x: { ticks: { color: "#64748b", font: { size: 11 } }, grid: { color: "#1e293b" } },
      y: { ticks: { color: "#64748b", font: { size: 11 } }, grid: { color: "#1e293b" } }
    }
  }
}

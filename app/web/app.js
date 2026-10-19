const dot = document.getElementById("db-dot");
const status = document.getElementById("db-status");
const detail = document.getElementById("db-detail");
const raw = document.getElementById("raw");

async function refresh() {
  try {
    const response = await fetch("/api/message", { headers: { Accept: "application/json" } });
    const body = await response.json();
    raw.textContent = JSON.stringify(body, null, 2);

    if (body.database?.connected) {
      dot.className = "dot ok";
      status.textContent = `connected · ${body.service} → postgres`;
      detail.textContent = `${body.database.message}\nserver time: ${body.database.serverTime ?? "n/a"}`;
    } else {
      dot.className = "dot bad";
      status.textContent = "database unreachable";
      detail.textContent = body.database?.error ?? "no database status returned";
    }
  } catch (error) {
    dot.className = "dot bad";
    status.textContent = "API unreachable";
    detail.textContent = String(error);
    raw.textContent = "—";
  }
}

refresh();
setInterval(refresh, 5000);

const denyBtn = document.getElementById("deny-btn");
const denyResult = document.getElementById("deny-result");

denyBtn.addEventListener("click", async () => {
  denyResult.textContent = "requesting /denied/healthz …";
  try {
    const response = await fetch("/denied/healthz", { cache: "no-store" });
    const body = await response.text();
    if (response.status === 504 || response.status === 502) {
      denyResult.textContent = `blocked as expected: HTTP ${response.status}\nThe connection timed out because Cilium dropped it.`;
    } else {
      denyResult.textContent = `unexpected reachable response: HTTP ${response.status}\n${body}`;
    }
  } catch (error) {
    denyResult.textContent = `blocked as expected: ${String(error)}\nThe connection was dropped by Cilium.`;
  }
});

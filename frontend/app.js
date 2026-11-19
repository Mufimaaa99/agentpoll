// AgentPoll frontend logic — vanilla JS + ethers v6 (CDN).
// Wallet connection uses the standard window.ethereum provider only.
// Every write (vote / create poll) is signed and confirmed in the user's own wallet.
(function () {
  const CFG = window.AGENTPOLL_CONFIG;
  const $ = (id) => document.getElementById(id);
  const statusEl = $("status"), errEl = $("error");

  let provider, signer, account, poll, gate, isOwner = false, hasId = false;

  function setErr(msg) { errEl.textContent = msg || ""; }
  function setStatus(msg) { statusEl.textContent = msg || ""; }

  function readProvider() {
    return new ethers.JsonRpcProvider(CFG.rpcUrl);
  }

  async function ensureChain() {
    const net = await provider.getNetwork();
    if (Number(net.chainId) !== CFG.chainId) {
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: "0x" + CFG.chainId.toString(16) }]
        });
      } catch (e) {
        if (e.code === 4902) {
          await window.ethereum.request({
            method: "wallet_addEthereumChain",
            params: [{
              chainId: "0x" + CFG.chainId.toString(16),
              chainName: CFG.chainName,
              rpcUrls: [CFG.rpcUrl],
              blockExplorerUrls: [CFG.explorerUrl],
              nativeCurrency: { name: CFG.nativeSymbol, symbol: CFG.nativeSymbol, decimals: 18 }
            }]
          });
        } else { throw e; }
      }
      provider = new ethers.BrowserProvider(window.ethereum);
    }
  }

  async function connect() {
    setErr("");
    if (!window.ethereum) { setErr("No wallet found. Open this page in a wallet dApp browser or install a standard Ethereum wallet extension."); return; }
    if (!CFG.pollAddress) { setErr("Contract address is not configured yet (see config.js)."); return; }
    provider = new ethers.BrowserProvider(window.ethereum);
    await provider.send("eth_requestAccounts", []);
    await ensureChain();
    signer = await provider.getSigner();
    account = (await signer.getAddress()).toLowerCase();
    poll = new ethers.Contract(CFG.pollAddress, CFG.pollAbi, signer);
    gate = new ethers.Contract(CFG.agentIdAddress, CFG.agentIdAbi, signer);

    $("connectBtn").textContent = "Connected";
    const acc = $("accountBadge");
    acc.style.display = ""; acc.textContent = account.slice(0, 6) + "…" + account.slice(-4);

    const bal = await gate.balanceOf(account);
    hasId = bal > 0n;
    const badge = $("agentBadge");
    badge.style.display = "";
    badge.className = "badge " + (hasId ? "ok" : "no");
    badge.textContent = hasId ? "Agent ID detected ✓ — you can vote" : "No Agent ID found — voting is disabled";

    const ownerAddr = (await poll.owner()).toLowerCase();
    isOwner = ownerAddr === account;
    $("ownerPanel").style.display = isOwner ? "" : "none";

    setStatus("Network: " + CFG.chainName);
    await renderPolls();
  }

  function fmtClose(closesAt) {
    const MAX = 18446744073709551615n;
    if (closesAt === MAX) return "no deadline";
    const d = new Date(Number(closesAt) * 1000);
    return (BigInt(Math.floor(Date.now() / 1000)) > closesAt ? "closed " : "closes ") + d.toLocaleString();
  }

  async function renderPolls() {
    const container = $("polls");
    container.innerHTML = "";
    // Read via plain RPC so the list also loads before wallet connect.
    const rp = readProvider();
    if (!CFG.pollAddress) { setStatus("Contract not deployed/configured yet."); return; }
    const readPoll = new ethers.Contract(CFG.pollAddress, CFG.pollAbi, rp);
    const count = Number(await readPoll.pollCount());
    if (count === 0) { container.innerHTML = '<div class="card">No polls yet.</div>'; return; }

    for (let id = count - 1; id >= 0; id--) {
      const [question, options, closesAt, totalVotes] = await readPoll.getPoll(id);
      const counts = await readPoll.getResults(id);
      const open = await readPoll.isOpen(id);
      let voted = false, myChoice = -1;
      if (account) {
        const c = await readPoll.choiceOf(id, account);
        voted = c[0]; myChoice = voted ? Number(c[1]) : -1;
      }
      const total = Number(totalVotes);
      const card = document.createElement("div");
      card.className = "card";
      let html = "<h3>" + escapeHtml(question) + "</h3>" +
        '<div class="meta">Poll #' + id + " · " + total + " vote(s) · " + fmtClose(closesAt) + "</div>";
      options.forEach((opt, i) => {
        const n = Number(counts[i]);
        const pct = total ? Math.round((n * 1000) / total) / 10 : 0;
        html += '<div class="opt"><div class="optrow"><span>' + escapeHtml(opt) +
          (i === myChoice ? ' <span class="mine">(your vote)</span>' : "") +
          "</span><span>" + n + " · " + pct + '%</span></div>' +
          '<div class="track"><div class="fill" style="width:' + pct + '%"></div></div>';
        if (account && open && !voted && hasId) {
          html += '<button data-vote="' + id + ':' + i + '">Vote</button>';
        }
        html += "</div>";
      });
      if (account && open && voted) html += '<div class="meta">You already voted in this poll — votes cannot be changed.</div>';
      if (account && open && !voted && !hasId) html += '<div class="meta">An Agent ID is required to vote in this poll.</div>';
      if (!open) html += '<div class="meta">This poll is closed.</div>';
      card.innerHTML = html;
      container.appendChild(card);
    }
    container.querySelectorAll("[data-vote]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const [pid, oi] = btn.dataset.vote.split(":").map(Number);
        btn.disabled = true;
        try {
          setErr(""); setStatus("Confirm the vote in your wallet…");
          const tx = await poll.vote(pid, oi);
          setStatus("Vote sent, waiting for confirmation…");
          await tx.wait();
          setStatus("Vote recorded on-chain ✓");
          await renderPolls();
        } catch (e) {
          setErr("Vote failed: " + (e.shortMessage || e.message));
          btn.disabled = false;
        }
      });
    });
  }

  async function createPoll() {
    setErr("");
    const q = $("newQuestion").value.trim();
    const opts = Array.from(document.querySelectorAll(".newOpt")).map((i) => i.value.trim()).filter(Boolean);
    const days = parseInt($("newDuration").value || "0", 10);
    if (!q) { setErr("Question is empty."); return; }
    if (opts.length < 2 || opts.length > 5) { setErr("Provide 2–5 options."); return; }
    try {
      setStatus("Confirm poll creation in your wallet…");
      const tx = await poll.createPoll(q, opts, BigInt(days) * 86400n);
      await tx.wait();
      setStatus("Poll created ✓");
      $("newQuestion").value = "";
      document.querySelectorAll(".newOpt").forEach((i) => (i.value = ""));
      await renderPolls();
    } catch (e) {
      setErr("Create failed: " + (e.shortMessage || e.message));
    }
  }

  function escapeHtml(s) {
    return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  }

  $("connectBtn").addEventListener("click", () => connect().catch((e) => setErr(e.message)));
  $("createBtn").addEventListener("click", createPoll);
  if (window.ethereum) {
    window.ethereum.on && window.ethereum.on("accountsChanged", () => location.reload());
    window.ethereum.on && window.ethereum.on("chainChanged", () => location.reload());
  }
  renderPolls().catch(() => {});
})();

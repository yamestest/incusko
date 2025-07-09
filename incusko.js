async function loadContainers() {
  const res = await fetch("/cgi-bin/list.sh");
  const data = await res.json();
  const tbody = document.getElementById("containerTable");
  tbody.innerHTML = "";

  for (const c of data) {
    const row = document.createElement("tr");

    const cpuText = c.cpu || '<span class="has-text-grey-light">∞</span>';
    const ramText = c.ram || '<span class="has-text-grey-light">∞</span>';

    row.innerHTML = `
      <td>${c.name}</td>
      <td>${c.status}</td>
      <td>${c.ipv4}</td>
      <td>${c.type}</td>
      <td>${cpuText}</td>
      <td>${ramText}</td>
      <td class="has-text-centered"></td>
      <td class="buttons is-flex is-flex-wrap-wrap"></td>
    `;

    const snapCell = row.children[6];
    const snapCount = parseInt(c.snapshots);

    if (snapCount > 0) {
      const snapLink = document.createElement("a");
      snapLink.href = "#";
      snapLink.textContent = c.snapshots;
      snapLink.onclick = e => {
        e.preventDefault();
        zobrazSnapshoty(c.name);
      };
      snapCell.appendChild(snapLink);
    } else {
      snapCell.textContent = "0";
    }

    const plusBtn = document.createElement("button");
    plusBtn.className = "button is-small is-success ml-5";
    plusBtn.textContent = "+";
    plusBtn.onclick = () => vytvorSnapshot(c.name);
    snapCell.appendChild(plusBtn);

    const actions = row.children[7];
    if (c.status === "RUNNING") {
      actions.appendChild(makeBtn("Terminal", "is-success", () => openTerminal(c.name)));
      actions.appendChild(makeBtn("Stop", "is-warning", () => control("stop", c.name)));
    }
    if (c.status === "STOPPED") {
      actions.appendChild(makeBtn("Štart", "is-primary", () => control("start", c.name)));
      actions.appendChild(makeBtn("Zmaž", "is-danger", () => { if (confirm(`Zmazať ${c.name}?`)) control("delete", c.name); }));      
    }

    tbody.appendChild(row);
  }
}

function makeBtn(text, bulmaClass, handler) {
  const btn = document.createElement("button");
  btn.className = `button ${bulmaClass} is-small m-1`;
  btn.textContent = text;
  btn.onclick = handler;
  return btn;
}

function control(cmd, name) {
  fetch(`/cgi-bin/control.sh?cmd=${cmd}&name=${name}`).then(() => loadContainers());
}

function openTerminal(name) {
  fetch(`/cgi-bin/terminal.sh?name=${name}`)
    .then(res => res.json())
    .then(result => {
      if (result.status === "success") {
        const url = `http://${location.hostname}:${result.port}`;
        window.open(url, "Terminal", "width=900,height=600,resizable=yes");
      } else {
        alert("Chyba pri ttyd: " + result.message);
      }
    });
}

function vytvorSnapshot(name) {
  fetch(`/cgi-bin/snapshot.sh?name=${encodeURIComponent(name)}`)
    .then(res => res.json())
    .then(result => {
      alert(result.message || `Snapshot vytvorený`);
      loadContainers();
    });
}

function zobrazSnapshoty(name) {
  fetch(`/cgi-bin/snaplist.sh?name=${encodeURIComponent(name)}`)
    .then(res => res.json())
    .then(snaps => {
      let html = "";
      if (!snaps.length) {
        html = `<div class="has-text-grey-light">Žiadne snapshoty.</div>`;
      } else {
        snaps.forEach(s => {
          html += `
            <div class="box">
              <p><strong>${s.name}</strong> — ${s.taken}</p>
              <p class="is-size-7">Stateful: ${s.stateful}</p>
              <div class="buttons mt-2">
                <button class="button is-small is-info" onclick="obnovSnapshot('${name}', '${s.name}')">🕰️ Obnoviť</button>
                <button class="button is-small is-danger" onclick="vymazSnapshot('${name}', '${s.name}')">🗑️ Zmazať</button>
              </div>
            </div>`;
        });
      }
      document.getElementById("snapshotContent").innerHTML = html;
      document.getElementById("snapshotsModal").classList.add("is-active");
    });
}

function obnovSnapshot(name, snap) {
  fetch(`/cgi-bin/restore.sh?name=${encodeURIComponent(name)}&snap=${encodeURIComponent(snap)}`)
    .then(res => res.json())
    .then(result => {
      alert(result.message || "Obnovené");
      zavriSnapshots();
      loadContainers();
    });
}

function vymazSnapshot(name, snap) {
  if (!confirm(`Naozaj chceš zmazať snapshot ${snap}?`)) return;
  fetch(`/cgi-bin/delete_snap.sh?name=${encodeURIComponent(name)}&snap=${encodeURIComponent(snap)}`)
    .then(res => res.json())
    .then(result => {
      alert(result.message || "Zmazané");
      zavriSnapshots();
      loadContainers();
    });
}

function zavriSnapshots() {
  document.getElementById("snapshotsModal").classList.remove("is-active");
}

function openCreateModal() {
  document.getElementById("createModal").classList.add("is-active");
  loadImageOptions();
}

function closeCreateModal() {
  document.getElementById("createModal").classList.remove("is-active");
}

document.getElementById("confirmBtn").onclick = () => {
  const name = document.getElementById("instanceName").value.trim();
  const image = document.getElementById("instanceImage").value;
  const cpu = document.getElementById("cpuLimit").value.trim();
  const ram = document.getElementById("ramLimit").value.trim();
  const disk = document.getElementById("diskLimit").value.trim();
  const url = `/cgi-bin/create.sh?name=${encodeURIComponent(name)}&image=${encodeURIComponent(image)}&cpu=${cpu}&ram=${ram}&disk=${disk}`;

  if (!name || !image) return alert("Zadaj meno a vyber obraz");
  closeCreateModal();
  fetch(url)
    .then(r => r.json())
    .then(res => {
      if (res.status === 'queued') {
        alert('Inštancia je v poradovníku, vytvorí sa čoskoro.');
        loadContainers();
      } else {
        // pôvodná logika
      }
    })
    .catch(e => alert('Chyba pri vytváraní: ' + e.message));
};

async function loadImageOptions() {
  const select = document.getElementById("instanceImage");
  select.innerHTML = "";

  try {
    const res = await fetch("/cgi-bin/images.sh");
    const images = await res.json();

    if (!images.length) {
      select.innerHTML = `<option disabled>Žiadne obrazy</option>`;
      return;
    }

    images.forEach(alias => {
      const opt = document.createElement("option");
      opt.value = alias;
      opt.textContent = alias.replace("images:", "");
      select.appendChild(opt);
    });
  } catch {
    select.innerHTML = `<option disabled>Chyba pri načítaní</option>`;
  }
}

// štart
loadContainers();
setInterval(loadContainers, 15000);

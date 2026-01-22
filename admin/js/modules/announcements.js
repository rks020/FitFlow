export async function loadAnnouncements() {
    const contentArea = document.getElementById('content-area');
    contentArea.innerHTML = `
        <div class="coming-soon">
            <h2>📢 Duyurular</h2>
            <p>Bu özellik yakında eklenecek...</p>
        </div>
    `;
}

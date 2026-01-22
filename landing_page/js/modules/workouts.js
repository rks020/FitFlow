export async function loadWorkouts() {
    const contentArea = document.getElementById('content-area');
    contentArea.innerHTML = `
        <div class="coming-soon">
            <h2>🏋️ Antrenman Programları</h2>
            <p>Bu özellik yakında eklenecek...</p>
        </div>
        <style>
            .coming-soon {
                text-align: center;
                padding: 80px 20px;
            }
            .coming-soon h2 {
                font-size: 32px;
                margin-bottom: 16px;
            }
            .coming-soon p {
                color: var(--text-secondary);
            }
        </style>
    `;
}

document.addEventListener('DOMContentLoaded', () => {
    // Component loader
    async function loadComponent(id, path) {
        const el = document.getElementById(id);
        if (!el) return;
        try {
            const res = await fetch(path);
            const html = await res.text();
            el.innerHTML = html;
        } catch (err) {
            console.error(`Error loading component ${id}:`, err);
        }
    }

    // Load shared components if applicable (though for static HTML we might just include them)
    // For this build, I'll include components directly in the HTML files to ensure everything works without a local server during dev
});

async function loadProducts(category = 'all') {
    const grid = document.getElementById('products-grid');
    if (!grid) return;

    try {
        const endpoint = category === 'all' ? '/products/' : `/products/?category=${category}`;
        const products = await api.get(endpoint);
        
        grid.innerHTML = products.map(p => `
            <div class="product-card">
                <div class="product-image">
                    <img src="${p.image_url}" alt="${p.name}">
                </div>
                <div class="product-info">
                    <p class="product-category">${p.category}</p>
                    <h3>${p.name}</h3>
                    <p class="product-price">$${p.price.toFixed(2)}</p>
                    <button class="btn btn-primary add-to-cart-btn" 
                        data-id="${p.id}" 
                        data-name="${p.name}" 
                        data-price="${p.price}" 
                        data-img="${p.image_url}">ADD TO ARMORY</button>
                </div>
            </div>
        `).join('');

        attachCartEvents();
    } catch (err) {
        console.error('Failed to load products:', err);
    }
}

function attachCartEvents() {
    document.querySelectorAll('.add-to-cart-btn').forEach(btn => {
        btn.onclick = () => {
            const product = {
                id: parseInt(btn.dataset.id),
                name: btn.dataset.name,
                price: parseFloat(btn.dataset.price),
                image_url: btn.dataset.img
            };
            cart.add(product);
        };
    });
}

document.addEventListener('DOMContentLoaded', () => {
    const filters = document.querySelectorAll('.filter-btn');
    filters.forEach(btn => {
        btn.onclick = () => {
            filters.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            loadProducts(btn.dataset.filter);
        };
    });
    
    loadProducts();
});

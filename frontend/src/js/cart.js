const cart = {
    items: JSON.parse(localStorage.getItem('bushido_cart')) || [],

    add(product) {
        const existing = this.items.find(i => i.id === product.id);
        if (existing) {
            existing.quantity++;
        } else {
            this.items.push({ ...product, quantity: 1 });
        }
        this.save();
        this.render();
    },

    remove(productId) {
        this.items = this.items.filter(i => i.id !== productId);
        this.save();
        this.render();
    },

    save() {
        localStorage.setItem('bushido_cart', JSON.stringify(this.items));
        this.updateBadge();
    },

    updateBadge() {
        const count = this.items.reduce((a, b) => a + b.quantity, 0);
        const badge = document.querySelector('.cart-trigger .count');
        if (badge) badge.innerText = count;
    },

    render() {
        const container = document.querySelector('.cart-items');
        if (!container) return;

        container.innerHTML = this.items.map(i => `
            <div class="cart-item">
                <img src="${i.image_url}" alt="${i.name}">
                <div class="cart-item-info">
                    <h4>${i.name}</h4>
                    <p>$${i.price} x ${i.quantity}</p>
                    <button class="btn-remove" onclick="cart.remove(${i.id})">REMOVE</button>
                </div>
            </div>
        `).join('');

        const total = this.items.reduce((a, b) => a + (b.price * b.quantity), 0);
        const totalEl = document.getElementById('cart-total-val');
        if (totalEl) totalEl.innerText = `$${total.toFixed(2)}`;
    }
};

window.cart = cart; // Global access
document.addEventListener('DOMContentLoaded', () => cart.updateBadge());

document.addEventListener('DOMContentLoaded', () => {
    const checkoutForm = document.getElementById('checkout-form');
    if (!checkoutForm) return;

    checkoutForm.onsubmit = async (e) => {
        e.preventDefault();
        const user = JSON.parse(localStorage.getItem('bushido_user'));
        if (!user) {
            alert('PLEASE LOGIN TO DEPLOY ORDER.');
            return;
        }

        const data = {
            address: document.getElementById('address').value,
            cart: cart.items
        };

        try {
            const res = await api.post('/orders/', data, user.token);
            if (res.order_id) {
                alert('ORDER DEPLOYED SUCCESSFULLY. PREPARE FOR ARRIVAL.');
                localStorage.removeItem('bushido_cart');
                window.location.href = 'index.html';
            }
        } catch (err) {
            alert('DEPLOYMENT FAILED. CHECK SYSTEM STATUS.');
        }
    };
});

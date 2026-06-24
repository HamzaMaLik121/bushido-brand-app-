from flask import Blueprint, jsonify, request
from src.middleware.auth import token_required
from src.models.product import db
from src.models.order import Order, OrderItem
from src.models.cart import CartItem

orders_bp = Blueprint('orders', __name__)

@orders_bp.route('/', methods=['POST'])
@token_required
def create_order(current_user):
    data = request.json
    address = data.get('address')
    
    cart_items = CartItem.query.filter_by(user_id=current_user.id).all()
    if not cart_items:
        return jsonify({'error': 'Cart is empty'}), 400
    
    total_amount = 0
    order = Order(user_id=current_user.id, total_amount=0, address=address)
    db.session.add(order)
    db.session.flush() # Get order.id
    
    for item in cart_items:
        from src.models.product import Product
        product = Product.query.get(item.product_id)
        price = product.price * item.quantity
        total_amount += price
        
        order_item = OrderItem(
            order_id=order.id,
            product_id=product.id,
            quantity=item.quantity,
            price=product.price
        )
        db.session.add(order_item)
        db.session.delete(item)
    
    order.total_amount = total_amount
    db.session.commit()
    
    return jsonify({'message': 'Order created successfully', 'order_id': order.id}), 201

@orders_bp.route('/', methods=['GET'])
@token_required
def get_orders(current_user):
    orders = Order.query.filter_by(user_id=current_user.id).all()
    output = []
    for order in orders:
        output.append({
            'id': order.id,
            'total_amount': float(order.total_amount),
            'status': order.status,
            'created_at': order.created_at.isoformat()
        })
    return jsonify(output)

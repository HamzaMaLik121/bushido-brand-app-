from flask import Blueprint, jsonify, request
from src.middleware.auth import token_required
from src.models.product import db
from src.models.cart import CartItem
from src.models.product import Product

cart_bp = Blueprint('cart', __name__)

@cart_bp.route('/', methods=['GET'])
@token_required
def get_cart(current_user):
    items = CartItem.query.filter_by(user_id=current_user.id).all()
    output = []
    for item in items:
        product = Product.query.get(item.product_id)
        output.append({
            'id': item.id,
            'product_id': product.id,
            'name': product.name,
            'price': float(product.price),
            'quantity': item.quantity,
            'image_url': product.image_url
        })
    return jsonify(output)

@cart_bp.route('/', methods=['POST'])
@token_required
def add_to_cart(current_user):
    data = request.json
    product_id = data.get('product_id')
    quantity = data.get('quantity', 1)

    item = CartItem.query.filter_by(user_id=current_user.id, product_id=product_id).first()
    if item:
        item.quantity += quantity
    else:
        new_item = CartItem(user_id=current_user.id, product_id=product_id, quantity=quantity)
        db.session.add(new_item)
    
    db.session.commit()
    return jsonify({'message': 'Item added to cart'})

@cart_bp.route('/<int:item_id>', methods=['DELETE'])
@token_required
def remove_from_cart(current_user, item_id):
    item = CartItem.query.filter_by(id=item_id, user_id=current_user.id).first_or_404()
    db.session.delete(item)
    db.session.commit()
    return jsonify({'message': 'Item removed from cart'})

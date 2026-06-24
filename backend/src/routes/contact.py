from flask import Blueprint, jsonify, request
from src.models.product import db
from src.models.cart import ContactMessage

contact_bp = Blueprint('contact', __name__)

@contact_bp.route('/', methods=['POST'])
def submit_contact():
    data = request.json
    new_message = ContactMessage(
        name=data['name'],
        email=data['email'],
        subject=data.get('subject', 'General Inquiry'),
        message=data['message']
    )
    db.session.add(new_message)
    db.session.commit()
    return jsonify({'message': 'Message received successfully'}), 201

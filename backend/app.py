from flask import Flask
from config import Config
from src.models.product import db
from src.middleware.cors import init_cors
from src.routes.products import products_bp
from src.routes.auth import auth_bp
from src.routes.cart import cart_bp
from src.routes.orders import orders_bp
from src.routes.contact import contact_bp

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)
    
    db.init_app(app)
    init_cors(app)
    
    with app.app_context():
        db.create_all()
    
    app.register_blueprint(products_bp, url_prefix='/api/products')
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(cart_bp, url_prefix='/api/cart')
    app.register_blueprint(orders_bp, url_prefix='/api/orders')
    app.register_blueprint(contact_bp, url_prefix='/api/contact')
    
    @app.route('/api/health')
    def health():
        return {"status": "healthy"}, 200
        
    return app

app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

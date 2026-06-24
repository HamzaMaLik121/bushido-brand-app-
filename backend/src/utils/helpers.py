def format_price(amount):
    return f"${amount:,.2f}"

def paginate(query, page, per_page):
    return query.paginate(page=page, per_page=per_page)

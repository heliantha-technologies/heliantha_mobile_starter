from pydantic import BaseModel, EmailStr, Field


class CheckoutLineIn(BaseModel):
    product_id: int
    product_attribute_id: int = 0
    quantity: int = Field(ge=1)


class CheckoutPreviewIn(BaseModel):
    lines: list[CheckoutLineIn]
    language_id: int | None = None
    currency_id: int | None = None
    country_id: int | None = None
    address_id: int | None = None
    carrier_id: int | None = None


class CheckoutGuestIn(BaseModel):
    title: str
    firstname: str
    lastname: str
    email: EmailStr
    create_account: bool = False
    password: str | None = None
    birthday: str | None = None


class CheckoutAddressIn(BaseModel):
    firstname: str
    lastname: str
    address1: str
    address2: str | None = None
    postcode: str | None = None
    city: str
    country_id: int | None = None
    phone: str | None = None


class CheckoutConfirmIn(CheckoutPreviewIn):
    mode: str
    idempotency_key: str
    guest: CheckoutGuestIn | None = None
    address: CheckoutAddressIn | None = None
    carrier_id: int | None = None
    payment_module: str | None = None


class CheckoutFieldOut(BaseModel):
    name: str
    label: str
    required: bool = True
    type: str = "text"
    options: list[str] = Field(default_factory=list)


class CheckoutLineOut(BaseModel):
    product_id: int
    product_attribute_id: int = 0
    name: str
    quantity: int
    unit_price: float
    total: float
    currency: str
    currency_symbol: str
    available: bool
    stock_quantity: int | None = None
    stock_message: str | None = None


class CheckoutCarrierOut(BaseModel):
    id: int
    name: str
    delay: str | None = None
    price: float | None = None
    price_label: str | None = None


class CheckoutPaymentOut(BaseModel):
    module: str
    name: str


class CheckoutTotalsOut(BaseModel):
    subtotal: float
    shipping: float | None = None
    shipping_label: str
    discounts: float = 0.0
    total_ttc: float
    taxes_included: bool = True
    currency: str
    currency_symbol: str
    source: str


class CheckoutPreviewOut(BaseModel):
    modes: list[str]
    personal_fields: list[CheckoutFieldOut]
    address_fields: list[CheckoutFieldOut]
    required_consents: list[CheckoutFieldOut]
    lines: list[CheckoutLineOut]
    totals: CheckoutTotalsOut
    carriers: list[CheckoutCarrierOut]
    payments: list[CheckoutPaymentOut]
    selected_carrier_id: int | None = None
    stock_ok: bool
    message: str | None = None
    write_enabled: bool
    bridge_required: list[str]

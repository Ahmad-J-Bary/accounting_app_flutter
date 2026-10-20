use std::str::FromStr;

use application::dto::invoice_dto::{
    CreateInvoiceRequest, InvoiceDto, InvoiceLineDto, UpdateInvoiceRequest,
};
use application::dto::payment_dto::{CreatePaymentRequest, PaymentDto, UpdatePaymentRequest};
use application::dto::returns_dto::{
    CreatePurchaseReturnRequest, CreateSalesReturnRequest, PurchaseReturnDto,
    PurchaseReturnLineDto, SalesReturnDto, SalesReturnLineDto,
};
use application::use_cases::payment::{
    CreatePaymentUseCase, DeletePaymentUseCase, ListPaymentsUseCase, UpdatePaymentUseCase,
};
use application::use_cases::purchase_return::{
    CreatePurchaseReturnUseCase, PostPurchaseReturnUseCase, PurchaseReturnQueries,
};
use application::use_cases::sales_return::{
    CreateSalesReturnUseCase, PostSalesReturnUseCase, SalesReturnQueries,
};
use application::use_cases::unified_invoice::{
    CreateInvoiceUseCase, DeleteInvoiceUseCase, InvoiceQueries, PostInvoiceDependencies,
    PostInvoiceUseCase, UpdateInvoiceUseCase,
};
use rust_decimal::Decimal;

use super::error::ApiError;

#[derive(Debug, Clone)]
pub struct InvoiceLineInput {
    pub material_id: String,
    pub quantity: String,
    pub unit_price: String,
    pub discount_percent: String,
    pub unit_id: Option<String>,
    pub conversion_factor: Option<String>,
    pub warehouse_id: Option<String>,
    pub notes: Option<String>,
}

#[derive(Debug, Clone)]
pub struct InvoiceInput {
    pub invoice_type: String,
    pub customer_id: Option<String>,
    pub customer_name: Option<String>,
    pub supplier_id: Option<String>,
    pub supplier_name: Option<String>,
    pub lines: Vec<InvoiceLineInput>,
    pub tax_amount: String,
    pub discount_amount: String,
    pub extra_costs: String,
    pub payment_method: String,
    pub amount_paid: String,
    pub issued_at: String,
    pub currency_code: String,
    pub exchange_rate: String,
    pub notes: Option<String>,
}

#[derive(Debug, Clone)]
pub struct InvoiceLineView {
    pub id: String,
    pub material_id: String,
    pub material_name: String,
    pub code: String,
    pub barcode: String,
    pub category_name: String,
    pub quantity: String,
    pub unit_id: Option<String>,
    pub conversion_factor: Option<String>,
    pub unit_price: String,
    pub purchase_price: String,
    pub discount_percent: String,
    pub line_total: String,
    pub notes: Option<String>,
}

#[derive(Debug, Clone)]
pub struct InvoiceView {
    pub id: String,
    pub invoice_number: String,
    pub invoice_type: String,
    pub party_id: Option<String>,
    pub party_name: String,
    pub status: String,
    pub lines: Vec<InvoiceLineView>,
    pub tax_amount: String,
    pub discount_amount: String,
    pub extra_costs: String,
    pub subtotal_amount: String,
    pub total_amount: String,
    pub amount_paid: String,
    pub remaining_amount: String,
    pub payment_method: String,
    pub issued_at: String,
    pub currency_code: String,
    pub exchange_rate: String,
    pub notes: Option<String>,
}

fn decimal(value: &str) -> Decimal {
    Decimal::from_str(value).unwrap_or(Decimal::ZERO)
}

fn line_total(quantity: &str, unit_price: &str, discount_percent: &str) -> String {
    let gross = decimal(quantity) * decimal(unit_price);
    let discount = decimal(discount_percent) / Decimal::from(100);
    (gross * (Decimal::ONE - discount)).round_dp(2).to_string()
}

fn to_line_dto(line: InvoiceLineInput) -> InvoiceLineDto {
    InvoiceLineDto {
        id: String::new(),
        material_id: line.material_id,
        material_name: None,
        barcode: None,
        code: None,
        category_name: None,
        quantity: line.quantity,
        unit_id: line.unit_id,
        conversion_factor: line.conversion_factor,
        unit_price: line.unit_price,
        unit_price_v2: None,
        purchase_price: None,
        purchase_price_v2: None,
        retail_price: None,
        retail_price_v2: None,
        wholesale_price: None,
        wholesale_price_v2: None,
        semi_wholesale_price: None,
        semi_wholesale_price_v2: None,
        minimum_stock: None,
        warehouse_id: line.warehouse_id,
        expiry_date: None,
        notes: line.notes,
        discount_percent: line.discount_percent,
        unit_price_original: None,
        purchase_price_original: None,
        profit_amount_original: None,
    }
}

fn invoice_view(dto: InvoiceDto) -> InvoiceView {
    let party_id = dto.customer_id.clone().or_else(|| dto.supplier_id.clone());
    let party_name = dto
        .customer_name
        .clone()
        .or_else(|| dto.supplier_name.clone())
        .unwrap_or_default();
    let lines = dto
        .lines
        .into_iter()
        .map(|line| InvoiceLineView {
            line_total: line_total(&line.quantity, &line.unit_price, &line.discount_percent),
            id: line.id,
            material_id: line.material_id,
            material_name: line.material_name.unwrap_or_default(),
            code: line.code.unwrap_or_default(),
            barcode: line.barcode.unwrap_or_default(),
            category_name: line.category_name.unwrap_or_default(),
            quantity: line.quantity,
            unit_id: line.unit_id,
            conversion_factor: line.conversion_factor,
            unit_price: line.unit_price,
            purchase_price: line.purchase_price.unwrap_or_default(),
            discount_percent: line.discount_percent,
            notes: line.notes,
        })
        .collect();

    InvoiceView {
        id: dto.id,
        invoice_number: dto.invoice_number,
        invoice_type: dto.invoice_type,
        party_id,
        party_name,
        status: dto.status,
        lines,
        tax_amount: dto.tax_amount,
        discount_amount: dto.discount_amount,
        extra_costs: dto.extra_costs,
        subtotal_amount: dto.subtotal_amount,
        total_amount: dto.total_amount,
        amount_paid: dto.amount_paid,
        remaining_amount: dto.remaining_amount,
        payment_method: dto.payment_method,
        issued_at: dto.issued_at,
        currency_code: dto.currency_code,
        exchange_rate: dto.exchange_rate,
        notes: dto.notes,
    }
}

fn create_request(input: &InvoiceInput) -> CreateInvoiceRequest {
    CreateInvoiceRequest {
        invoice_number: String::new(),
        invoice_type: input.invoice_type.clone(),
        customer_id: input.customer_id.clone(),
        customer_name: input.customer_name.clone(),
        supplier_id: input.supplier_id.clone(),
        supplier_name: input.supplier_name.clone(),
        lines: input.lines.clone().into_iter().map(to_line_dto).collect(),
        tax_amount: input.tax_amount.clone(),
        discount_amount: input.discount_amount.clone(),
        extra_costs: Some(input.extra_costs.clone()),
        payment_method: input.payment_method.clone(),
        amount_paid: input.amount_paid.clone(),
        issued_at: input.issued_at.clone(),
        currency_code: input.currency_code.clone(),
        exchange_rate: input.exchange_rate.clone(),
        notes: input.notes.clone(),
    }
}

pub async fn list_invoices(invoice_type: String) -> Result<Vec<InvoiceView>, ApiError> {
    let app = super::accounting::state()?;
    let invoices = InvoiceQueries::new(
        app.unified_invoice_repo.clone(),
        app.material_repo.clone(),
        app.customer_repo.clone(),
        app.supplier_repo.clone(),
        app.category_repo.clone(),
    )
    .list_by_type(invoice_type)
    .await?;
    Ok(invoices.into_iter().map(invoice_view).collect())
}

pub async fn get_invoice(id: String) -> Result<InvoiceView, ApiError> {
    let app = super::accounting::state()?;
    let invoice = InvoiceQueries::new(
        app.unified_invoice_repo.clone(),
        app.material_repo.clone(),
        app.customer_repo.clone(),
        app.supplier_repo.clone(),
        app.category_repo.clone(),
    )
    .get_by_id(id)
    .await?;
    Ok(invoice_view(invoice))
}

pub async fn next_invoice_number(invoice_type: String) -> Result<String, ApiError> {
    let app = super::accounting::state()?;
    Ok(InvoiceQueries::new(
        app.unified_invoice_repo.clone(),
        app.material_repo.clone(),
        app.customer_repo.clone(),
        app.supplier_repo.clone(),
        app.category_repo.clone(),
    )
    .get_next_invoice_number(invoice_type)
    .await?)
}

pub async fn create_invoice(input: InvoiceInput, post: bool) -> Result<InvoiceView, ApiError> {
    let app = super::accounting::state()?;
    let dto = CreateInvoiceUseCase::new(
        app.unified_invoice_repo.clone(),
        app.customer_repo.clone(),
        app.supplier_repo.clone(),
        app.account_repo.clone(),
        app.material_repo.clone(),
        app.category_repo.clone(),
        app.journal_entry_repo.clone(),
        app.opening_migration_repo.clone(),
    )
    .execute(create_request(&input))
    .await?;

    if post {
        post_invoice(dto.id).await
    } else {
        Ok(invoice_view(dto))
    }
}

pub async fn update_invoice(id: String, input: InvoiceInput) -> Result<InvoiceView, ApiError> {
    let app = super::accounting::state()?;
    let request = UpdateInvoiceRequest {
        id,
        customer_id: input.customer_id,
        customer_name: input.customer_name,
        supplier_id: input.supplier_id,
        supplier_name: input.supplier_name,
        lines: input.lines.into_iter().map(to_line_dto).collect(),
        tax_amount: input.tax_amount,
        discount_amount: input.discount_amount,
        extra_costs: Some(input.extra_costs),
        notes: input.notes,
    };
    let dto = UpdateInvoiceUseCase::new(
        app.unified_invoice_repo.clone(),
        app.customer_repo.clone(),
        app.supplier_repo.clone(),
        app.account_repo.clone(),
        app.material_repo.clone(),
        app.category_repo.clone(),
        app.journal_entry_repo.clone(),
        app.opening_migration_repo.clone(),
    )
    .execute(request)
    .await?;
    Ok(invoice_view(dto))
}

pub async fn post_invoice(id: String) -> Result<InvoiceView, ApiError> {
    let app = super::accounting::state()?;
    let dto = PostInvoiceUseCase::new(PostInvoiceDependencies {
        repo: app.unified_invoice_repo.clone(),
        movement_repo: app.stock_movement_repo.clone(),
        lot_repo: app.inventory_lot_repo.clone(),
        journal_repo: app.journal_entry_repo.clone(),
        account_repo: app.account_repo.clone(),
        customer_repo: app.customer_repo.clone(),
        supplier_repo: app.supplier_repo.clone(),
        material_repo: app.material_repo.clone(),
        category_repo: app.category_repo.clone(),
        currency_repo: app.currency_repo.clone(),
        exchange_rate_repo: app.exchange_rate_repo.clone(),
        opening_migration_repo: app.opening_migration_repo.clone(),
    })
    .execute(id)
    .await?;
    Ok(invoice_view(dto))
}

pub async fn delete_invoice(id: String) -> Result<(), ApiError> {
    let app = super::accounting::state()?;
    DeleteInvoiceUseCase::new(
        app.unified_invoice_repo.clone(),
        app.stock_movement_repo.clone(),
        app.journal_entry_repo.clone(),
        app.customer_repo.clone(),
        app.supplier_repo.clone(),
        app.currency_repo.clone(),
        app.exchange_rate_repo.clone(),
        app.payment_repo.clone(),
    )
    .execute(id)
    .await?;
    Ok(())
}

#[derive(Debug, Clone)]
pub struct ReturnLineInput {
    pub material_id: String,
    pub quantity: String,
    pub unit_price: String,
    pub unit_id: Option<String>,
    pub notes: Option<String>,
    pub invoice_line_id: Option<String>,
}

#[derive(Debug, Clone)]
pub struct ReturnLineView {
    pub id: String,
    pub material_id: String,
    pub material_name: String,
    pub quantity: String,
    pub unit_price: String,
    pub unit_id: Option<String>,
    pub line_total: String,
    pub notes: Option<String>,
}

#[derive(Debug, Clone)]
pub struct ReturnView {
    pub id: String,
    pub return_number: String,
    pub party_id: String,
    pub party_name: String,
    pub return_date: String,
    pub lines: Vec<ReturnLineView>,
    pub total_amount: String,
    pub notes: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Clone)]
pub struct ReturnInput {
    pub party_id: String,
    pub return_date: String,
    pub lines: Vec<ReturnLineInput>,
    pub notes: Option<String>,
    pub settlement_mode: Option<String>,
    pub settlement_amount: Option<String>,
    pub is_paid: bool,
}

fn sales_line_dto(line: ReturnLineInput) -> SalesReturnLineDto {
    SalesReturnLineDto {
        id: String::new(),
        material_id: line.material_id,
        material_name: None,
        quantity: line.quantity,
        unit_price: line.unit_price,
        unit_id: line.unit_id,
        line_total: String::new(),
        notes: line.notes,
        invoice_line_id: line.invoice_line_id,
    }
}

fn purchase_line_dto(line: ReturnLineInput) -> PurchaseReturnLineDto {
    PurchaseReturnLineDto {
        id: String::new(),
        material_id: line.material_id,
        material_name: None,
        quantity: line.quantity,
        unit_price: line.unit_price,
        unit_id: line.unit_id,
        line_total: String::new(),
        notes: line.notes,
        invoice_line_id: line.invoice_line_id,
    }
}

fn sales_return_view(dto: SalesReturnDto) -> ReturnView {
    ReturnView {
        id: dto.id,
        return_number: dto.return_number,
        party_id: dto.customer_id,
        party_name: dto.customer_name.unwrap_or_default(),
        return_date: dto.return_date,
        lines: dto
            .lines
            .into_iter()
            .map(|line| ReturnLineView {
                id: line.id,
                material_id: line.material_id,
                material_name: line.material_name.unwrap_or_default(),
                quantity: line.quantity,
                unit_price: line.unit_price,
                unit_id: line.unit_id,
                line_total: line.line_total,
                notes: line.notes,
            })
            .collect(),
        total_amount: dto.total_amount,
        notes: dto.notes,
        created_at: dto.created_at,
    }
}

fn purchase_return_view(dto: PurchaseReturnDto) -> ReturnView {
    ReturnView {
        id: dto.id,
        return_number: dto.return_number,
        party_id: dto.supplier_id,
        party_name: dto.supplier_name.unwrap_or_default(),
        return_date: dto.return_date,
        lines: dto
            .lines
            .into_iter()
            .map(|line| ReturnLineView {
                id: line.id,
                material_id: line.material_id,
                material_name: line.material_name.unwrap_or_default(),
                quantity: line.quantity,
                unit_price: line.unit_price,
                unit_id: line.unit_id,
                line_total: line.line_total,
                notes: line.notes,
            })
            .collect(),
        total_amount: dto.total_amount,
        notes: dto.notes,
        created_at: dto.created_at,
    }
}

pub async fn list_sales_returns() -> Result<Vec<ReturnView>, ApiError> {
    let app = super::accounting::state()?;
    let returns = SalesReturnQueries::new(
        app.sales_return_repo.clone(),
        app.customer_repo.clone(),
        app.material_repo.clone(),
    )
    .list_all()
    .await?;
    Ok(returns.into_iter().map(sales_return_view).collect())
}

pub async fn create_sales_return(input: ReturnInput) -> Result<ReturnView, ApiError> {
    let app = super::accounting::state()?;
    let return_number = app.sales_return_repo.get_next_return_number().await?;
    let dto =
        CreateSalesReturnUseCase::new(app.sales_return_repo.clone(), app.customer_repo.clone())
            .execute(CreateSalesReturnRequest {
                id: None,
                return_number,
                customer_id: input.party_id,
                customer_name: None,
                return_date: input.return_date,
                lines: input.lines.into_iter().map(sales_line_dto).collect(),
                notes: input.notes,
                settlement_mode: input.settlement_mode.clone(),
                settlement_amount: input.settlement_amount.clone(),
                is_paid: Some(input.is_paid),
            })
            .await?;

    let posted = PostSalesReturnUseCase::new(
        app.sales_return_repo.clone(),
        app.stock_movement_repo.clone(),
        app.journal_entry_repo.clone(),
        app.account_repo.clone(),
        app.customer_repo.clone(),
        app.material_repo.clone(),
        app.currency_repo.clone(),
        app.exchange_rate_repo.clone(),
        app.fiscal_year_repo.clone(),
        app.fiscal_period_repo.clone(),
    )
    .execute(
        dto.id,
        input.settlement_mode,
        input.settlement_amount,
        Some(input.is_paid),
    )
    .await?;
    Ok(sales_return_view(posted))
}

pub async fn list_purchase_returns() -> Result<Vec<ReturnView>, ApiError> {
    let app = super::accounting::state()?;
    let returns = PurchaseReturnQueries::new(
        app.purchase_return_repo.clone(),
        app.supplier_repo.clone(),
        app.material_repo.clone(),
    )
    .list_all()
    .await?;
    Ok(returns.into_iter().map(purchase_return_view).collect())
}

pub async fn create_purchase_return(input: ReturnInput) -> Result<ReturnView, ApiError> {
    let app = super::accounting::state()?;
    let return_number = app.purchase_return_repo.get_next_return_number().await?;
    let dto = CreatePurchaseReturnUseCase::new(
        app.purchase_return_repo.clone(),
        app.supplier_repo.clone(),
    )
    .execute(CreatePurchaseReturnRequest {
        id: None,
        return_number,
        supplier_id: input.party_id,
        supplier_name: None,
        return_date: input.return_date,
        lines: input.lines.into_iter().map(purchase_line_dto).collect(),
        notes: input.notes,
        settlement_mode: input.settlement_mode.clone(),
        settlement_amount: input.settlement_amount.clone(),
        is_paid: Some(input.is_paid),
    })
    .await?;

    let posted = PostPurchaseReturnUseCase::new(
        app.purchase_return_repo.clone(),
        app.stock_movement_repo.clone(),
        app.journal_entry_repo.clone(),
        app.account_repo.clone(),
        app.supplier_repo.clone(),
        app.material_repo.clone(),
        app.currency_repo.clone(),
        app.exchange_rate_repo.clone(),
        app.fiscal_year_repo.clone(),
        app.fiscal_period_repo.clone(),
    )
    .execute(
        dto.id,
        input.settlement_mode,
        input.settlement_amount,
        Some(input.is_paid),
    )
    .await?;
    Ok(purchase_return_view(posted))
}

pub async fn next_return_number(kind: String) -> Result<String, ApiError> {
    let app = super::accounting::state()?;
    if kind == "Purchase" {
        Ok(app.purchase_return_repo.get_next_return_number().await?)
    } else {
        Ok(app.sales_return_repo.get_next_return_number().await?)
    }
}

#[derive(Debug, Clone)]
pub struct PaymentInput {
    pub payment_type: String,
    pub amount: String,
    pub currency_code: String,
    pub exchange_rate: String,
    pub payment_date: String,
    pub debit_account_id: Option<String>,
    pub credit_account_id: Option<String>,
    pub customer_id: Option<String>,
    pub supplier_id: Option<String>,
    pub reference: Option<String>,
    pub notes: Option<String>,
}

#[derive(Debug, Clone)]
pub struct PaymentView {
    pub id: String,
    pub voucher_number: String,
    pub payment_type: String,
    pub amount: String,
    pub currency_code: String,
    pub exchange_rate: String,
    pub payment_date: String,
    pub journal_entry_number: Option<String>,
    pub customer_id: Option<String>,
    pub customer_name: Option<String>,
    pub supplier_id: Option<String>,
    pub supplier_name: Option<String>,
    pub reference: Option<String>,
    pub notes: Option<String>,
    pub created_at: String,
}

fn payment_view(dto: PaymentDto) -> PaymentView {
    PaymentView {
        id: dto.id,
        voucher_number: dto.voucher_number,
        payment_type: dto.payment_type,
        amount: dto.amount,
        currency_code: dto.currency_code,
        exchange_rate: dto.exchange_rate,
        payment_date: dto.payment_date,
        journal_entry_number: dto.journal_entry_number,
        customer_id: dto.customer_id,
        customer_name: dto.customer_name,
        supplier_id: dto.supplier_id,
        supplier_name: dto.supplier_name,
        reference: dto.reference,
        notes: dto.notes,
        created_at: dto.created_at,
    }
}

pub async fn list_payments() -> Result<Vec<PaymentView>, ApiError> {
    let app = super::accounting::state()?;
    let payments = ListPaymentsUseCase::new(
        app.payment_repo.clone(),
        app.customer_repo.clone(),
        app.supplier_repo.clone(),
    )
    .execute(None, None)
    .await?;
    Ok(payments.into_iter().map(payment_view).collect())
}

pub async fn create_payment(input: PaymentInput) -> Result<PaymentView, ApiError> {
    let app = super::accounting::state()?;
    let dto = CreatePaymentUseCase::new(
        app.payment_repo.clone(),
        app.customer_repo.clone(),
        app.supplier_repo.clone(),
        app.journal_entry_repo.clone(),
        app.account_repo.clone(),
        app.fiscal_year_repo.clone(),
        app.fiscal_period_repo.clone(),
    )
    .execute(CreatePaymentRequest {
        voucher_number: None,
        payment_type: input.payment_type,
        amount: input.amount,
        currency_code: Some(input.currency_code),
        exchange_rate: Some(input.exchange_rate),
        payment_date: input.payment_date,
        debit_account_id: input.debit_account_id,
        credit_account_id: input.credit_account_id,
        customer_id: input.customer_id,
        supplier_id: input.supplier_id,
        reference: input.reference,
        notes: input.notes,
    })
    .await?;
    Ok(payment_view(dto))
}

pub async fn update_payment(id: String, input: PaymentInput) -> Result<PaymentView, ApiError> {
    let app = super::accounting::state()?;
    let dto = UpdatePaymentUseCase::new(
        app.payment_repo.clone(),
        app.customer_repo.clone(),
        app.supplier_repo.clone(),
        app.journal_entry_repo.clone(),
        app.account_repo.clone(),
        app.fiscal_year_repo.clone(),
        app.fiscal_period_repo.clone(),
    )
    .execute(UpdatePaymentRequest {
        id,
        voucher_number: None,
        payment_type: input.payment_type,
        amount: input.amount,
        currency_code: Some(input.currency_code),
        exchange_rate: Some(input.exchange_rate),
        payment_date: input.payment_date,
        debit_account_id: input.debit_account_id,
        credit_account_id: input.credit_account_id,
        customer_id: input.customer_id,
        supplier_id: input.supplier_id,
        reference: input.reference,
        notes: input.notes,
    })
    .await?;
    Ok(payment_view(dto))
}

pub async fn delete_payment(id: String) -> Result<(), ApiError> {
    let app = super::accounting::state()?;
    DeletePaymentUseCase::new(
        app.payment_repo.clone(),
        app.customer_repo.clone(),
        app.supplier_repo.clone(),
        app.account_repo.clone(),
        app.journal_entry_repo.clone(),
    )
    .execute(id)
    .await?;
    Ok(())
}

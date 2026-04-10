package org.pwte.example.domain;

import java.io.Serializable;
import java.util.Set;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.DiscriminatorColumn;
import jakarta.persistence.DiscriminatorType;
import jakarta.persistence.Embedded;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.Inheritance;
import jakarta.persistence.InheritanceType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.json.bind.annotation.JsonbTransient;

@Entity
@Table(name = "CUSTOMER")
@Inheritance(strategy = InheritanceType.SINGLE_TABLE)
@DiscriminatorColumn(name = "TYPE", discriminatorType = DiscriminatorType.STRING)
public abstract class AbstractCustomer implements Serializable {

	private static final long serialVersionUID = -4988539679853665972L;

	public AbstractCustomer() {

	}

	@Id
	@Column(name = "CUSTOMER_ID")

	protected int customerId;
	protected String name;
	protected String type;
	@Column(name = "USERNAME", table = "CUSTOMER")
	protected String user;

	@Embedded
	protected Address address;

	@OneToOne(fetch = FetchType.EAGER, cascade = { CascadeType.MERGE, CascadeType.REFRESH }, optional = true)
	@JoinColumn(name = "OPEN_ORDER", referencedColumnName = "ORDER_ID")
	protected Order openOrder;

	@OneToMany(mappedBy = "customer", fetch = FetchType.LAZY)
	protected Set<Order> orders;

	@JsonbTransient
	public Set<Order> getOrders() {
		return orders;
	}

	public void setOrders(Set<Order> orders) {
		this.orders = orders;
	}

	public Order getOpenOrder() {
		return openOrder;
	}

	public void setOpenOrder(Order openOrder) {
		this.openOrder = openOrder;
	}

	public Address getAddress() {
		return address;
	}

	public void setAddress(Address address) {
		this.address = address;
	}

	@JsonIgnore
	public int getCustomerId() {
		return customerId;
	}

	@JsonIgnore
	public void setCustomerId(int customerId) {
		this.customerId = customerId;
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public String getType() {
		return type;
	}

	public void setType(String type) {
		this.type = type;
	}

	@JsonIgnore
	public String getUser() {
		return user;
	}

	@JsonIgnore
	public void setUser(String user) {
		this.user = user;
	}

}

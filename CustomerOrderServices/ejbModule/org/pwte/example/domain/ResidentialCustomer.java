package org.pwte.example.domain;

import java.io.Serializable;

import jakarta.persistence.Column;
import jakarta.persistence.DiscriminatorValue;
import jakarta.persistence.Entity;
import jakarta.persistence.Basic;


@Entity
@DiscriminatorValue("RESIDENTIAL")
public class ResidentialCustomer extends AbstractCustomer implements
		Serializable {
	
	private static final long serialVersionUID = -6734139231865273295L;

	public ResidentialCustomer() {
		// TODO Auto-generated constructor stub
	}
	
	@Column(name="RESIDENTIAL_HOUSEHOLD_SIZE")
	protected short householdSize;
	
	
	@Column(name="RESIDENTIAL_FREQUENT_CUSTOMER")
	protected String frequentCustomer;


	public short getHouseholdSize() {
		return householdSize;
	}


	public void setHouseholdSize(short householdSize) {
		this.householdSize = householdSize;
	}


	public boolean isFrequentCustomer() {
		return "Y".equals(frequentCustomer);
	}


	public void setFrequentCustomer(String frequentCustomer) {
		this.frequentCustomer = frequentCustomer;
	}


	
	
	
}
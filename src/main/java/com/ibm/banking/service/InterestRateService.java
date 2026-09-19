package com.ibm.banking.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Year;

public class InterestRateService {

    public BigDecimal calculateAnnualInterest(BigDecimal principal, BigDecimal annualRatePercentage) {
        if (principal == null || annualRatePercentage == null || principal.compareTo(BigDecimal.ZERO) <= 0) {
            return BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);
        }
        return principal.multiply(annualRatePercentage)
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
    }

    public BigDecimal calculateDailyInterest(BigDecimal principal, BigDecimal annualRatePercentage, int year) {
        BigDecimal annualInterest = calculateAnnualInterest(principal, annualRatePercentage);
        int daysInYear = isLeapYear(year) ? 366 : 365;
        return annualInterest.divide(BigDecimal.valueOf(daysInYear), 4, RoundingMode.HALF_UP);
    }

    public boolean isLeapYear(int year) {
        return Year.isLeap(year);
    }
}

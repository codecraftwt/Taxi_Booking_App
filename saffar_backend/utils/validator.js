class Validator {
  // Email Regular Expression
  static emailRegex =
    /^[-!#$%&'*+\/0-9=?A-Z^_a-z{|}~](\.?[-!#$%&'*+\/0-9=?A-Z^_a-z`{|}~])*@[a-zA-Z0-9](-*\.?[a-zA-Z0-9])*\.[a-zA-Z](-?[a-zA-Z0-9])+$/;

  /// Checks if name length is between 1 and 1000
  static validateName(name) {
    if (!name) {
      return false;
    }

    if (name.length <= 0 || name.length > 1000) {
      return false;
    }

    return true;
  }

  /// Validates Email address
  static validateEmail(email) {
    if (!email) {
      return false;
    }

    if (email.length > 254) {
      return false;
    }

    const valid = this.emailRegex.test(email);
    if (!valid) {
      return false;
    }

    const emailParts = email.split("@");
    if (emailParts[0].length > 64) {
      return false;
    }

    const domainParts = emailParts[1].split(".");
    if (domainParts.some((part) => part.length > 63)) {
      return false;
    }

    return true;
  }

  /// Checking if phone number length is 10 and is numeric
  static validatePhone(phone) {
    if (!phone) {
      return false;
    }

    if (phone.length !== 10) {
      return false;
    }

    return !isNaN(Number(phone));
  }

  /// Validates if password length is at least 8
  static validatePassword(password) {
    if (!password) {
      return false;
    }

    return password.length >= 8;
  }

  /// Validates vehicle number plate
  static validateVehicleNumber(vehicleNumber) {
    if (!vehicleNumber) {
      return false;
    }

    const numberPlateRegex =
      /^[A-Z]{2}[0-9]{2}[A-HJ-NP-Z]{1,2}[0-9]{4}$/;
    return numberPlateRegex.test(vehicleNumber);
  }
}

module.exports = Validator;


class Helper {
  static getObjectWithIdInsteadOf_idAnd__v = (doc) => {
    const { _id, __v, ...rest } = doc.toObject();
    rest.id = _id.toString();
    return rest;
  };

  static getRandomInt(max) {
    return Math.floor(Math.random() * max);
  }

  static generatePhone() {
    let phone = "";
    for (let index = 0; index < 10; index++) {
      phone += this.getRandomInt(10);
    }
    return phone;
  }
}

module.exports = Helper;


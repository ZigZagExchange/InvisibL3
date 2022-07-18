const fs = require("fs");

console.time("read");
fs.readFile("myjsonfile.json", "utf-8", (err, data) => {
  const inputData = JSON.parse(data.toString());

  let swaps = inputData.swaps;
  swaps.push({
    orderA: {
      amout_spent: "1",
      amount_received: "2",
      fee_limit: "3",
      nonce: "4",
      expiration_timestamp: "5",
      pub_view_key: "6",
    },
    orderB: {
      amout_spent: "1",
      amount_received: "2",
      fee_limit: "3",
      nonce: "4",
      expiration_timestamp: "5",
      pub_view_key: "6",
    },
    spentAmountA: "1",
    spentAmountB: "2",
    feeTakenA: "3",
    feeTakenB: "4",
  });

  inputData.swaps = swaps;

  let inputDataString = JSON.stringify(inputData, (key, value) => {
    return typeof value === "bigint" ? value.toString() : value;
  });

  fs.writeFile("myjsonfile.json", inputDataString, (err) => {
    if (err) {
      console.log(err);
    }
  });
});
console.timeEnd("read");

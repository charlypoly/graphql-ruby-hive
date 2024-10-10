const express = require("express");
const app = express();
const port = 8888;

app.use(express.json());

let count = 0;

app.get("/", (req, res) => {
  res.status(200).send({ status: "ok" });
});

app.get("/count", (req, res) => {
  res.status(200).json({ count });
});

app.post("/reset", (req, res) => {
  count = 0;
  res.status(200).send({ count });
});

app.post("/usage", (req, res) => {
  if (req.body && req.body.operations) {
    count += Object.keys(req.body.operations).length;
  }
  res.status(200).send({ status: "ok " });
});

app.listen(port, () => {
  console.log(`Usage API listening on port ${port}`);
});

import express from "express";

const app = express();

app.get("/", (req, res) => {
  res.send("Hello World from DevopsGithubJenkinsCI/CD....");
});

app.get('/Contact', (req, res) => {
  res.json({ "message": "Hello, You can contact us by email: Chandanimagar66@gmail.com." })
})

app.listen(3000, () => {
  console.log("Server is running on http://localhost:3000");
});


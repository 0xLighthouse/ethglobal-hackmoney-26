import { db } from "ponder:api";
import schema from "ponder:schema";
import { graphql } from "ponder";
import { Hono } from "hono";

const app = new Hono();

app.get("/", (c) => c.text("Indexer running"));
app.use("/graphql", graphql({ db, schema }));

export default app;

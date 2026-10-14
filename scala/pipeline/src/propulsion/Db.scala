package propulsion

import java.sql.{Connection, DriverManager, ResultSet}
import java.nio.file.{Files, Path, Paths}

/** Thin JDBC access to the DuckDB file. No connection pool and no ORM: the pipeline opens
  * one connection, does its work and closes it.
  */
object Db:

  private val relativePath = Paths.get("data", "propulsion.duckdb")

  /** Locate data/propulsion.duckdb by walking up from the working directory.
    *
    * Mill runs tasks with the working directory set to the build root, which is `scala/`
    * rather than the repository root, so a bare relative path would miss. PROPULSION_DB
    * overrides the search.
    */
  def defaultPath: String =
    sys.env.get("PROPULSION_DB").filter(_.nonEmpty) match
      case Some(explicit) => explicit
      case None =>
        def search(dir: Path): Option[Path] =
          if dir == null then None
          else
            val candidate = dir.resolve(relativePath)
            if Files.exists(candidate) then Some(candidate) else search(dir.getParent)
        search(Paths.get("").toAbsolutePath)
          .map(_.toString)
          .getOrElse(
            throw IllegalStateException(
              "could not find data/propulsion.duckdb walking up from " +
                Paths.get("").toAbsolutePath +
                ". Build it with: duckdb data/propulsion.duckdb < sql/schema.sql"
            )
          )

  def url(path: String): String = s"jdbc:duckdb:$path"

  /** Open a connection, run `f`, and close the connection whatever happens. */
  def withConnection[A](path: => String = defaultPath)(f: Connection => A): A =
    Class.forName("org.duckdb.DuckDBDriver")
    val conn = DriverManager.getConnection(url(path))
    try f(conn)
    finally conn.close()

  /** Run a query and map every row with `f`. */
  def query[A](conn: Connection, sql: String)(f: ResultSet => A): Vector[A] =
    val st = conn.createStatement()
    try
      val rs = st.executeQuery(sql)
      val buf = Vector.newBuilder[A]
      while rs.next() do buf += f(rs)
      buf.result()
    finally st.close()

  def queryOneLong(conn: Connection, sql: String): Long =
    query(conn, sql)(_.getLong(1)).headOption.getOrElse(0L)

  // ResultSet getters that map SQL NULL to None rather than to 0.0 / 0 / null.

  def optDouble(rs: ResultSet, col: String): Option[Double] =
    val v = rs.getDouble(col)
    if rs.wasNull() then None else Some(v)

  def optInt(rs: ResultSet, col: String): Option[Int] =
    val v = rs.getInt(col)
    if rs.wasNull() then None else Some(v)

  def optString(rs: ResultSet, col: String): Option[String] =
    Option(rs.getString(col))

  def str(rs: ResultSet, col: String): String =
    val v = rs.getString(col)
    if v == null then throw IllegalStateException(s"unexpected NULL in non-null column $col")
    else v

  def dbl(rs: ResultSet, col: String): Double =
    val v = rs.getDouble(col)
    if rs.wasNull() then throw IllegalStateException(s"unexpected NULL in non-null column $col")
    else v

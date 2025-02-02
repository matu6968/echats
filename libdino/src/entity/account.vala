using Gee;
using Xmpp;

namespace Dino.Entities {

public class Account : Object {

    public int id { get; set; }
    public string localpart { get { return full_jid.localpart; } }
    public string domainpart { get { return full_jid.domainpart; } }
    public string resourcepart { get { return full_jid.resourcepart;} }
    public Jid bare_jid { owned get { return full_jid.bare_jid; } }
    public Jid full_jid { get; private set; }
    public string? password { get; set; }
    public string display_name {
        owned get { return (alias != null && alias.length > 0) ? alias.dup() : bare_jid.to_string(); }
    }
    public string? alias { get; set; }
    public bool enabled { get; set; default = false; }
    public string? roster_version { get; set; }

    private Database? db;

    public Account(Jid bare_jid, string? resourcepart, string? password, string? alias) {
        this.id = -1;
        if (resourcepart != null) {
            try {
                this.full_jid = bare_jid.with_resource(resourcepart);
            } catch (InvalidJidError e) {
                warning("Tried to create account with invalid resource (%s), defaulting to auto generated", e.message);
            }
        }
        if (this.full_jid == null) {
            try {
                this.full_jid = bare_jid.with_resource("echats." + Random.next_int().to_string("%x"));
            } catch (InvalidJidError e) {
                error("Auto-generated resource was invalid (%s)", e.message);
            }
        }
        this.password = password;
        this.alias = alias;
    }

    public Account.from_row(Database db, Qlite.Row row) throws InvalidJidError {
        this.db = db;
        id = row[db.account.id];
        full_jid = new Jid(row[db.account.bare_jid]).with_resource(row[db.account.resourcepart]);
        password = row[db.account.password];
        alias = row[db.account.alias];
        enabled = row[db.account.enabled];
        roster_version = row[db.account.roster_version];

        notify.connect(on_update);
    }

    public void persist(Database db) {
        if (id > 0) return;

        this.db = db;
        id = (int) db.account.insert()
                .value(db.account.bare_jid, bare_jid.to_string())
                .value(db.account.resourcepart, resourcepart)
                .value(db.account.password, password)
                .value(db.account.alias, alias)
                .value(db.account.enabled, enabled)
                .value(db.account.roster_version, roster_version)
                .perform();

        notify.connect(on_update);
    }

    public void remove() {
        db.account.delete().with(db.account.bare_jid, "=", bare_jid.to_string()).perform();
        notify.disconnect(on_update);
        id = -1;
        db = null;
    }

    public bool equals(Account acc) {
        return equals_func(this, acc);
    }

    public static bool equals_func(Account acc1, Account acc2) {
        return acc1.bare_jid.to_string() == acc2.bare_jid.to_string();
    }

    public static uint hash_func(Account acc) {
        return acc.bare_jid.to_string().hash();
    }

    private void on_update(Object o, ParamSpec sp) {
        var update = db.account.update().with(db.account.id, "=", id);
        switch (sp.name) {
            case "bare-jid":
                update.set(db.account.bare_jid, bare_jid.to_string()); break;
            case "resourcepart":
                update.set(db.account.resourcepart, resourcepart); break;
            case "password":
                update.set(db.account.password, password); break;
            case "alias":
                update.set(db.account.alias, alias); break;
            case "enabled":
                update.set(db.account.enabled, enabled); break;
            case "roster-version":
                update.set(db.account.roster_version, roster_version); break;
        }
        update.perform();
    }
}

}

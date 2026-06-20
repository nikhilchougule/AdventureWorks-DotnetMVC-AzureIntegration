using AdventureWorks.Web.Data;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace AdventureWorks.Web.Repositories
{
    public class Repository<T> : IRepository<T> where T : class
    {
        protected readonly AdventureWorksContext _context;

        public Repository(AdventureWorksContext context)
        {
            _context = context;
        }

        public void Add(T entity)
        {
            _context.Set<T>().Add(entity);
        }

        public IQueryable<T> GetAll()
        {
            // throw new NotImplementedException();
            return _context.Set<T>();
        }

        public T GetById(int id)
        {
            //throw new NotImplementedException();
            return _context.Set<T>().Find(id);
        }

        public void Remove(T entity)
        {
            _context.Set<T>().Remove(entity);
        }
    }
}